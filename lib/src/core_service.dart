import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:permission_handler/permission_handler.dart' show Permission;

import 'config.dart';

/// Core auto-updater service (framework-agnostic).
///
/// This class handles all the update logic without any UI framework dependencies.
/// Use this directly or wrap it with a framework-specific adapter (e.g., GetX).
class AutoUpdaterCore {
  final AutoUpdaterConfig config;

  PackageInfo? _packageInfo;
  http.Client? _httpClient;
  String? _deviceArchitecture;
  bool _isInitialized = false;
  bool _isCheckingForUpdate = false;
  bool _isDownloading = false;

  AutoUpdaterCore({required this.config});

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Whether currently checking for updates
  bool get isCheckingForUpdate => _isCheckingForUpdate;

  /// Whether currently downloading an update
  bool get isDownloading => _isDownloading;

  /// The detected device architecture (Android only)
  String? get deviceArchitecture => _deviceArchitecture;

  /// Current app version info (available after initialization)
  CurrentVersionInfo? get currentVersion {
    if (_packageInfo == null) return null;
    final rawBuild = int.tryParse(_packageInfo!.buildNumber) ?? 0;
    return CurrentVersionInfo(
      version: _packageInfo!.version,
      build: _normalizeBuildNumber(rawBuild),
    );
  }

  /// Normalize build number by removing ABI offset added by Flutter's split APK builds.
  ///
  /// When using `flutter build apk --split-per-abi`, Flutter adds ABI-specific offsets:
  /// - armeabi-v7a: +1000
  /// - arm64-v8a: +2000
  /// - x86_64: +3000
  ///
  /// This method detects and removes the offset based on the device's architecture.
  int _normalizeBuildNumber(int rawBuild) {
    if (!Platform.isAndroid || _deviceArchitecture == null) {
      return rawBuild;
    }

    // Determine expected ABI offset based on device architecture
    int abiOffset;
    switch (_deviceArchitecture) {
      case 'armeabi-v7a':
        abiOffset = 1000;
        break;
      case 'arm64-v8a':
        abiOffset = 2000;
        break;
      case 'x86_64':
        abiOffset = 3000;
        break;
      case 'x86':
        abiOffset = 4000;
        break;
      default:
        return rawBuild;
    }

    // Check if the build number has the ABI offset applied
    // If rawBuild is in the range [abiOffset, abiOffset + 1000), it's a split APK
    if (rawBuild >= abiOffset && rawBuild < abiOffset + 1000) {
      final normalized = rawBuild - abiOffset;
      config.log('Normalized build number: $rawBuild -> $normalized (removed $abiOffset offset for $_deviceArchitecture)');
      return normalized;
    }

    // Not a split APK build, return as-is
    return rawBuild;
  }

  /// Get debug info string for troubleshooting
  String getDebugInfo() {
    if (_packageInfo == null) return 'Not initialized';
    final rawBuild = int.tryParse(_packageInfo!.buildNumber) ?? 0;
    final normalizedBuild = _normalizeBuildNumber(rawBuild);
    return '''
=== AutoUpdater Debug Info ===
Version: ${_packageInfo!.version}
Build Number (raw): $rawBuild
Build Number (normalized): $normalizedBuild
Architecture: $_deviceArchitecture
ABI Offset Detected: ${rawBuild != normalizedBuild ? 'Yes (${rawBuild - normalizedBuild})' : 'No'}
Base URL: ${config.baseUrl}
Project: ${config.appId}
Channel: ${config.environment}
ReleaseHub Mode: ${config.releaseHubMode}
Check URL: ${config.versionCheckUrlWithArch(_deviceArchitecture, currentVersion: _packageInfo!.version, currentBuild: normalizedBuild)}
==============================''';
  }

  /// Initialize the service. Must be called before using other methods.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _deviceArchitecture = _detectArchitecture();
      _isInitialized = true;

      config.log(
        'Initialized - version: ${_packageInfo!.version}, '
        'build: ${_packageInfo!.buildNumber}, '
        'arch: $_deviceArchitecture',
      );
    } catch (e) {
      config.log('Failed to initialize: $e');
      rethrow;
    }
  }

  /// Detect the device's CPU architecture for split APK selection
  String? _detectArchitecture() {
    if (!Platform.isAndroid) return null;

    final abi = Abi.current();

    switch (abi) {
      case Abi.androidArm64:
        return 'arm64-v8a';
      case Abi.androidArm:
        return 'armeabi-v7a';
      case Abi.androidX64:
        return 'x86_64';
      case Abi.androidIA32:
        return 'x86';
      default:
        config.log('Unknown Android ABI: $abi, defaulting to arm64-v8a');
        return 'arm64-v8a';
    }
  }

  /// Check for available updates.
  ///
  /// Returns an [UpdateCheckResult] indicating whether an update is available,
  /// no update is needed, or an error occurred.
  Future<UpdateCheckResult> checkForUpdate() async {
    if (config.isDisabled) {
      config.log('Update check disabled');
      return const UpdateCheckDisabled();
    }

    if (_isCheckingForUpdate) {
      config.log('Already checking for updates');
      return const UpdateCheckError('Already checking for updates');
    }

    if (!_isInitialized || _packageInfo == null) {
      config.log('Service not initialized');
      return const UpdateCheckError('Service not initialized');
    }

    _isCheckingForUpdate = true;

    try {
      final currentVersion = _packageInfo!.version;
      final rawBuild = int.tryParse(_packageInfo!.buildNumber) ?? 0;
      final currentBuild = _normalizeBuildNumber(rawBuild);

      config.log('=== UPDATE CHECK DEBUG ===');
      config.log('Package info - version: $currentVersion, buildNumber: ${_packageInfo!.buildNumber}');
      config.log('Raw build number: $rawBuild');
      config.log('Normalized build number: $currentBuild');
      config.log('Device architecture: $_deviceArchitecture');

      final url = config.versionCheckUrlWithArch(
        _deviceArchitecture,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );
      config.log('Request URL: $url');

      final request = http.Request('GET', Uri.parse(url));
      if (config.httpHeaders != null) {
        request.headers.addAll(config.httpHeaders!);
      }

      final client = http.Client();
      try {
        final streamedResponse = await client.send(request).timeout(
          config.connectionTimeout,
        );
        final response = await http.Response.fromStream(streamedResponse);

        config.log('Response status: ${response.statusCode}');
        config.log('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final versionData = json.decode(response.body) as Map<String, dynamic>;
          config.log('Parsed JSON: $versionData');

          // Handle ReleaseHub mode vs standard mode
          if (config.releaseHubMode) {
            // ReleaseHub returns hasUpdate flag directly
            final hasUpdate = versionData['hasUpdate'] as bool? ?? false;
            config.log('ReleaseHub hasUpdate flag: $hasUpdate');

            if (!hasUpdate) {
              config.log('No update available (ReleaseHub: hasUpdate=false)');
              config.log('=== END DEBUG ===');
              return const NoUpdateAvailable();
            }

            final versionInfo = VersionInfo.fromReleaseHub(versionData, config.baseUrl);

            config.log(
              'Version check - Current: $currentVersion (build $currentBuild), '
              'Server: ${versionInfo.version} (build ${versionInfo.build})',
            );

            config.log('New version available: ${versionInfo.displayVersion}');
            return UpdateAvailable(versionInfo);
          } else {
            // Standard mode - parse flat JSON
            final versionInfo = VersionInfo.fromJson(versionData, config.responseFields);

            config.log(
              'Version check - Current: $currentVersion (build $currentBuild), '
              'Server: ${versionInfo.version} (build ${versionInfo.build})',
            );

            if (_isNewerVersion(currentVersion, currentBuild, versionInfo)) {
              config.log('New version available: ${versionInfo.displayVersion}');
              return UpdateAvailable(versionInfo);
            } else {
              config.log('No update available - already on latest version');
              return const NoUpdateAvailable();
            }
          }
        } else if (response.statusCode == 404 && config.releaseHubMode) {
          // ReleaseHub returns 404 when project not found
          config.log('ReleaseHub: Project not found (404)');
          return const UpdateCheckError('Project not found on update server');
        } else {
          config.log('Version check failed with status: ${response.statusCode}');
          return UpdateCheckError(
            'Server returned status ${response.statusCode}',
          );
        }
      } finally {
        client.close();
      }
    } catch (e) {
      config.log('Error checking for update: $e');
      return UpdateCheckError('Could not check for updates', e);
    } finally {
      _isCheckingForUpdate = false;
    }
  }

  /// Compare versions to determine if server version is newer
  bool _isNewerVersion(
    String currentVersion,
    int currentBuild,
    VersionInfo serverInfo,
  ) {
    // First compare build numbers (more reliable)
    if (serverInfo.build > currentBuild) return true;
    if (serverInfo.build < currentBuild) return false;

    // If builds are equal, compare version strings
    final currentParts = currentVersion
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final serverParts = serverInfo.version
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    // Ensure both have same number of parts
    while (currentParts.length < serverParts.length) {
      currentParts.add(0);
    }
    while (serverParts.length < currentParts.length) {
      serverParts.add(0);
    }

    for (int i = 0; i < currentParts.length; i++) {
      if (serverParts[i] > currentParts[i]) return true;
      if (serverParts[i] < currentParts[i]) return false;
    }

    return false;
  }

  /// Request necessary permissions for installing APKs on Android.
  ///
  /// Returns true if permissions are granted, false otherwise.
  /// The [onPermissionDialogRequired] callback is called when the user
  /// needs to be informed about the permission request.
  Future<bool> requestInstallPermissions({
    Future<bool> Function()? onPermissionDialogRequired,
  }) async {
    if (!Platform.isAndroid) return true;
    if (config.skipPermissionCheck) return true;

    final installPermission = await Permission.requestInstallPackages.status;
    config.log('Install packages permission status: $installPermission');

    if (!installPermission.isGranted) {
      config.log('Requesting install packages permission...');

      if (onPermissionDialogRequired != null) {
        final shouldRequest = await onPermissionDialogRequired();
        if (!shouldRequest) {
          config.log('User declined permission dialog');
          return false;
        }
      }

      final result = await Permission.requestInstallPackages.request();
      config.log('Install permission request result: $result');

      if (!result.isGranted) {
        return false;
      }
    }

    // Storage permission for saving APK
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      final result = await Permission.storage.request();
      if (!result.isGranted) {
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      }
    }

    return true;
  }

  /// Open app settings for manual permission configuration
  Future<bool> openAppSettings() async {
    return await permission_handler.openAppSettings();
  }

  /// Download an APK file.
  ///
  /// [apkUrl] - The URL to download from
  /// [version] - Version string for the filename
  /// [onProgress] - Callback for download progress updates
  ///
  /// Returns a [DownloadResult] indicating success, error, or cancellation.
  Future<DownloadResult> downloadApk(
    String apkUrl,
    String version, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    if (_isDownloading) {
      return const DownloadError('Download already in progress');
    }

    _isDownloading = true;
    _httpClient = http.Client();

    try {
      onProgress?.call(const DownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        progress: 0,
        status: 'Starting download...',
      ));

      final request = http.Request('GET', Uri.parse(apkUrl));
      if (config.httpHeaders != null) {
        request.headers.addAll(config.httpHeaders!);
      }

      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        final bytes = <int>[];
        int downloadedBytes = 0;

        onProgress?.call(DownloadProgress(
          downloadedBytes: 0,
          totalBytes: contentLength,
          progress: 0,
          status: 'Downloading... (${DownloadProgress.formatBytes(contentLength)})',
        ));

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          downloadedBytes += chunk.length;

          if (contentLength > 0) {
            final progress = downloadedBytes / contentLength;
            onProgress?.call(DownloadProgress(
              downloadedBytes: downloadedBytes,
              totalBytes: contentLength,
              progress: progress,
              status: 'Downloaded ${DownloadProgress.formatBytes(downloadedBytes)} '
                  'of ${DownloadProgress.formatBytes(contentLength)}',
            ));
          }
        }

        onProgress?.call(DownloadProgress(
          downloadedBytes: downloadedBytes,
          totalBytes: contentLength,
          progress: 1.0,
          status: 'Download complete. Saving...',
        ));

        // Save APK file
        final saveDir = await _getDownloadDirectory();
        final filename = config.generateApkFilename(version);
        final apkFile = File('${saveDir.path}/$filename');
        await apkFile.writeAsBytes(bytes);

        config.log('APK saved to: ${apkFile.path}');
        return DownloadSuccess(apkFile.path);
      } else {
        return DownloadError('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      config.log('Download error: $e');
      return DownloadError('Could not download update', e);
    } finally {
      _isDownloading = false;
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Cancel an ongoing download
  void cancelDownload() {
    _httpClient?.close();
    _httpClient = null;
    _isDownloading = false;
  }

  /// Get the directory for saving downloaded APKs
  Future<Directory> _getDownloadDirectory() async {
    Directory saveDir;
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      saveDir = Directory(
        '${externalDir?.path ?? (await getTemporaryDirectory()).path}/Download',
      );
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
    } else {
      saveDir = await getTemporaryDirectory();
    }
    return saveDir;
  }

  /// Install a downloaded APK file.
  ///
  /// [filePath] - Path to the APK file
  ///
  /// Returns an [InstallResult] indicating the outcome.
  Future<InstallResult> installApk(String filePath) async {
    config.log('Installing APK from: $filePath');

    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type == ResultType.done) {
        config.log('Installation triggered successfully');
        return const InstallSuccess();
      } else {
        config.log('OpenFilex failed: ${result.type} - ${result.message}');
        return InstallManualRequired(filePath);
      }
    } catch (e) {
      config.log('Installation error: $e');
      return InstallError('Could not open installer', e);
    }
  }

  /// Clean up downloaded APK files
  Future<void> cleanupDownloads() async {
    try {
      final saveDir = await _getDownloadDirectory();
      final files = saveDir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.apk')) {
          await file.delete();
          config.log('Deleted: ${file.path}');
        }
      }
    } catch (e) {
      config.log('Cleanup error: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _httpClient?.close();
  }
}
