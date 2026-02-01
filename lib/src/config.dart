import 'package:flutter/material.dart';

/// Configuration for the auto-updater plugin.
///
/// All fields are optional with sensible defaults, making the plugin
/// highly configurable while still being easy to use out of the box.
class AutoUpdaterConfig {
  /// Base URL for the version check endpoint.
  /// The final URL will be: `$baseUrl/$versionPath/$appId/$environment`
  /// For ReleaseHub mode: `$baseUrl/$versionPath/$appId?version=X&build=N&channel=$environment&arch=Y`
  final String baseUrl;

  /// Path segment for version checking (default: 'version')
  /// For ReleaseHub mode, this is typically 'api/check'
  final String versionPath;

  /// Unique identifier for your app (e.g., 'com.example.myapp')
  /// For ReleaseHub, this can be the project slug or bundle_id
  final String appId;

  /// Environment/flavor name (e.g., 'dev', 'staging', 'prod')
  /// For ReleaseHub mode, this is used as the channel name
  final String environment;

  /// Enable ReleaseHub API format compatibility.
  /// When true, uses ReleaseHub's nested response format and URL structure.
  final bool releaseHubMode;

  /// Whether to automatically check for updates on service initialization
  final bool checkOnStartup;

  /// Delay before the startup check (to let the app fully initialize)
  final Duration startupDelay;

  /// Skip the Android install packages permission dialog
  final bool skipPermissionCheck;

  /// Completely disable the auto-updater
  final bool isDisabled;

  /// Custom filename pattern for downloaded APK.
  /// Placeholders: {appId}, {version}, {environment}
  /// Default: '{appId}_update_{version}.apk'
  final String apkFilenamePattern;

  /// Whether to include device architecture in version check URL
  final bool includeArchitecture;

  /// Custom HTTP headers for version check and download requests
  final Map<String, String>? httpHeaders;

  /// Connection timeout for HTTP requests
  final Duration connectionTimeout;

  /// Custom JSON field names for parsing version response
  final VersionResponseFields responseFields;

  /// Callback for custom logging (defaults to debugPrint)
  final void Function(String message)? logger;

  const AutoUpdaterConfig({
    required this.baseUrl,
    required this.appId,
    this.versionPath = 'version',
    this.environment = 'prod',
    this.releaseHubMode = false,
    this.checkOnStartup = true,
    this.startupDelay = const Duration(seconds: 2),
    this.skipPermissionCheck = false,
    this.isDisabled = false,
    this.apkFilenamePattern = '{appId}_update_{version}.apk',
    this.includeArchitecture = true,
    this.httpHeaders,
    this.connectionTimeout = const Duration(seconds: 30),
    this.responseFields = const VersionResponseFields(),
    this.logger,
  });

  /// Factory constructor for ReleaseHub backends
  factory AutoUpdaterConfig.releaseHub({
    required String baseUrl,
    required String projectSlug,
    String channel = 'stable',
    bool checkOnStartup = true,
    Duration startupDelay = const Duration(seconds: 2),
    bool skipPermissionCheck = false,
    bool isDisabled = false,
    String apkFilenamePattern = '{appId}_update_{version}.apk',
    Map<String, String>? httpHeaders,
    Duration connectionTimeout = const Duration(seconds: 30),
    void Function(String message)? logger,
  }) {
    return AutoUpdaterConfig(
      baseUrl: baseUrl,
      appId: projectSlug,
      versionPath: 'api/check',
      environment: channel,
      releaseHubMode: true,
      checkOnStartup: checkOnStartup,
      startupDelay: startupDelay,
      skipPermissionCheck: skipPermissionCheck,
      isDisabled: isDisabled,
      apkFilenamePattern: apkFilenamePattern,
      includeArchitecture: true,
      httpHeaders: httpHeaders,
      connectionTimeout: connectionTimeout,
      responseFields: const VersionResponseFields(), // Ignored in ReleaseHub mode
      logger: logger,
    );
  }

  /// Creates the full version check URL
  String get versionCheckUrl {
    if (releaseHubMode) {
      return '$baseUrl/$versionPath/$appId';
    }
    return '$baseUrl/$versionPath/$appId/$environment';
  }

  /// Creates the version check URL with optional architecture parameter
  /// For ReleaseHub mode, includes version, build, channel, and arch as query params
  String versionCheckUrlWithArch(String? arch, {String? currentVersion, int? currentBuild}) {
    if (releaseHubMode) {
      final params = <String, String>{
        if (currentVersion != null) 'version': currentVersion,
        if (currentBuild != null) 'build': currentBuild.toString(),
        'channel': environment,
        if (includeArchitecture && arch != null && arch.isNotEmpty) 'arch': arch,
      };
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      return '$versionCheckUrl?$query';
    }

    final base = versionCheckUrl;
    if (includeArchitecture && arch != null && arch.isNotEmpty) {
      return '$base?arch=$arch';
    }
    return base;
  }

  /// Generates the APK filename from the pattern
  String generateApkFilename(String version) {
    return apkFilenamePattern
        .replaceAll('{appId}', appId.replaceAll('.', '_'))
        .replaceAll('{version}', version)
        .replaceAll('{environment}', environment);
  }

  /// Log helper that uses custom logger or debugPrint
  void log(String message) {
    if (logger != null) {
      logger!(message);
    } else {
      debugPrint('[AutoUpdater] $message');
    }
  }

  /// Creates a copy with modified values
  AutoUpdaterConfig copyWith({
    String? baseUrl,
    String? versionPath,
    String? appId,
    String? environment,
    bool? releaseHubMode,
    bool? checkOnStartup,
    Duration? startupDelay,
    bool? skipPermissionCheck,
    bool? isDisabled,
    String? apkFilenamePattern,
    bool? includeArchitecture,
    Map<String, String>? httpHeaders,
    Duration? connectionTimeout,
    VersionResponseFields? responseFields,
    void Function(String message)? logger,
  }) {
    return AutoUpdaterConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      versionPath: versionPath ?? this.versionPath,
      appId: appId ?? this.appId,
      environment: environment ?? this.environment,
      releaseHubMode: releaseHubMode ?? this.releaseHubMode,
      checkOnStartup: checkOnStartup ?? this.checkOnStartup,
      startupDelay: startupDelay ?? this.startupDelay,
      skipPermissionCheck: skipPermissionCheck ?? this.skipPermissionCheck,
      isDisabled: isDisabled ?? this.isDisabled,
      apkFilenamePattern: apkFilenamePattern ?? this.apkFilenamePattern,
      includeArchitecture: includeArchitecture ?? this.includeArchitecture,
      httpHeaders: httpHeaders ?? this.httpHeaders,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      responseFields: responseFields ?? this.responseFields,
      logger: logger ?? this.logger,
    );
  }
}

/// Configuration for parsing the version check JSON response.
/// Allows customization of field names for different backend implementations.
class VersionResponseFields {
  /// Field name for version string (e.g., "1.2.3")
  final String version;

  /// Field name for build number (e.g., 42)
  final String build;

  /// Field name for APK download URL
  final String apkUrl;

  /// Field name for display version string (optional, falls back to version)
  final String? versionString;

  /// Field name for release notes (optional)
  final String? releaseNotes;

  /// Field name for minimum supported version (optional, for force update)
  final String? minVersion;

  /// Field name for whether update is required (optional)
  final String? isRequired;

  const VersionResponseFields({
    this.version = 'version',
    this.build = 'build',
    this.apkUrl = 'apk',
    this.versionString,
    this.releaseNotes,
    this.minVersion,
    this.isRequired,
  });
}

/// Parsed version information from the server
class VersionInfo {
  final String version;
  final int build;
  final String apkUrl;
  final String displayVersion;
  final String? releaseNotes;
  final String? minVersion;
  final bool isRequired;

  const VersionInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.displayVersion,
    this.releaseNotes,
    this.minVersion,
    this.isRequired = false,
  });

  factory VersionInfo.fromJson(
    Map<String, dynamic> json,
    VersionResponseFields fields,
  ) {
    return VersionInfo(
      version: json[fields.version] as String,
      build: json[fields.build] as int,
      apkUrl: json[fields.apkUrl] as String,
      displayVersion: (fields.versionString != null
              ? json[fields.versionString]
              : json[fields.version]) as String,
      releaseNotes:
          fields.releaseNotes != null ? json[fields.releaseNotes] as String? : null,
      minVersion:
          fields.minVersion != null ? json[fields.minVersion] as String? : null,
      isRequired: fields.isRequired != null
          ? (json[fields.isRequired] as bool?) ?? false
          : false,
    );
  }

  /// Parse ReleaseHub response format
  factory VersionInfo.fromReleaseHub(
    Map<String, dynamic> json,
    String baseUrl,
  ) {
    final latestVersion = json['latestVersion'] as Map<String, dynamic>;
    final download = json['download'] as Map<String, dynamic>;

    // Handle relative and absolute URLs
    String apkUrl = download['url'] as String;
    if (!apkUrl.startsWith('http')) {
      // Remove leading slash if present to avoid double slashes
      if (apkUrl.startsWith('/')) {
        apkUrl = apkUrl.substring(1);
      }
      apkUrl = '$baseUrl/$apkUrl';
    }

    return VersionInfo(
      version: latestVersion['version'] as String,
      build: latestVersion['build'] as int,
      apkUrl: apkUrl,
      displayVersion: latestVersion['versionString'] as String? ??
          '${latestVersion['version']}+${latestVersion['build']}',
      releaseNotes: latestVersion['releaseNotes'] as String?,
      minVersion: latestVersion['minVersion'] as String?,
      isRequired: (latestVersion['isRequired'] as bool?) ?? false,
    );
  }
}

/// Current app version information
class CurrentVersionInfo {
  final String version;
  final int build;

  const CurrentVersionInfo({
    required this.version,
    required this.build,
  });
}

/// Update check result
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  final VersionInfo versionInfo;
  const UpdateAvailable(this.versionInfo);
}

class NoUpdateAvailable extends UpdateCheckResult {
  const NoUpdateAvailable();
}

class UpdateCheckError extends UpdateCheckResult {
  final String message;
  final Object? error;
  const UpdateCheckError(this.message, [this.error]);
}

class UpdateCheckDisabled extends UpdateCheckResult {
  const UpdateCheckDisabled();
}

/// Download progress information
class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final String status;

  const DownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.status,
  });

  String get formattedProgress => '${(progress * 100).toStringAsFixed(0)}%';
  String get formattedDownloaded => formatBytes(downloadedBytes);
  String get formattedTotal => formatBytes(totalBytes);

  /// Format bytes to human-readable string (e.g., "1.5 MB")
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Download result
sealed class DownloadResult {
  const DownloadResult();
}

class DownloadSuccess extends DownloadResult {
  final String filePath;
  const DownloadSuccess(this.filePath);
}

class DownloadError extends DownloadResult {
  final String message;
  final Object? error;
  const DownloadError(this.message, [this.error]);
}

class DownloadCancelled extends DownloadResult {
  const DownloadCancelled();
}

/// Installation result
sealed class InstallResult {
  const InstallResult();
}

class InstallSuccess extends InstallResult {
  const InstallSuccess();
}

class InstallManualRequired extends InstallResult {
  final String filePath;
  const InstallManualRequired(this.filePath);
}

class InstallError extends InstallResult {
  final String message;
  final Object? error;
  const InstallError(this.message, [this.error]);
}

class InstallPermissionDenied extends InstallResult {
  const InstallPermissionDenied();
}
