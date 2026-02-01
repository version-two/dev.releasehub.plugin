import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config.dart';
import '../core_service.dart';

/// GetX-based auto-updater service.
///
/// This adapter wraps [AutoUpdaterCore] and provides reactive state management
/// via GetX observables. It also integrates with GetX navigation for dialogs.
///
/// Usage:
/// ```dart
/// // Register the service
/// Get.put(AutoUpdaterGetxService(config: myConfig), permanent: true);
///
/// // Use in your widgets
/// final updater = Get.find<AutoUpdaterGetxService>();
/// Obx(() => updater.isDownloading.value ? ProgressIndicator() : Container())
/// ```
class AutoUpdaterGetxService extends GetxService {
  final AutoUpdaterCore _core;

  /// Reactive state: whether currently checking for updates
  final RxBool isCheckingForUpdate = false.obs;

  /// Reactive state: whether currently downloading
  final RxBool isDownloading = false.obs;

  /// Reactive state: download progress (0.0 to 1.0)
  final RxDouble downloadProgress = 0.0.obs;

  /// Reactive state: download status message
  final RxString downloadStatus = ''.obs;

  /// Reactive state: last update check result
  final Rx<UpdateCheckResult?> lastCheckResult = Rx<UpdateCheckResult?>(null);

  /// UI customization callbacks
  final AutoUpdaterUICallbacks? uiCallbacks;

  AutoUpdaterGetxService({
    required AutoUpdaterConfig config,
    this.uiCallbacks,
  }) : _core = AutoUpdaterCore(config: config);

  /// Access to the underlying configuration
  AutoUpdaterConfig get config => _core.config;

  /// Current app version info
  CurrentVersionInfo? get currentVersion => _core.currentVersion;

  /// Device architecture (Android only)
  String? get deviceArchitecture => _core.deviceArchitecture;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    await _core.initialize();

    config.log(
      'AutoUpdaterGetxService.onInit - '
      'checkOnStartup: ${config.checkOnStartup}, '
      'isDisabled: ${config.isDisabled}, '
      'arch: ${_core.deviceArchitecture}',
    );

    if (config.checkOnStartup && !config.isDisabled) {
      config.log('Scheduling update check after ${config.startupDelay.inSeconds} seconds');
      Future.delayed(config.startupDelay, () => checkForUpdate(silent: true));
    }
  }

  /// Check for updates.
  ///
  /// [silent] - If true, no UI feedback is shown for "no update" or errors.
  Future<UpdateCheckResult> checkForUpdate({bool silent = true}) async {
    if (config.isDisabled) {
      config.log('Version update service is disabled');
      if (!silent) {
        _showDisabledSnackbar();
      }
      return const UpdateCheckDisabled();
    }

    if (isCheckingForUpdate.value) {
      return const UpdateCheckError('Already checking');
    }

    isCheckingForUpdate.value = true;

    try {
      final result = await _core.checkForUpdate();
      lastCheckResult.value = result;

      switch (result) {
        case UpdateAvailable(versionInfo: final info):
          _showUpdateAvailableUI(info);
        case NoUpdateAvailable():
          if (!silent) {
            _showNoUpdateSnackbar();
          }
        case UpdateCheckError(message: final msg):
          if (!silent) {
            _showErrorSnackbar('Update Check Failed', msg);
          }
        case UpdateCheckDisabled():
          if (!silent) {
            _showDisabledSnackbar();
          }
      }

      return result;
    } finally {
      isCheckingForUpdate.value = false;
    }
  }

  /// Start the download and installation flow for a version.
  Future<void> downloadAndInstall(VersionInfo versionInfo) async {
    if (isDownloading.value) return;

    // Request permissions
    final hasPermission = await _core.requestInstallPermissions(
      onPermissionDialogRequired: _showPermissionDialog,
    );

    if (!hasPermission) {
      _showPermissionDeniedSnackbar();
      return;
    }

    isDownloading.value = true;
    downloadProgress.value = 0.0;
    downloadStatus.value = 'Starting download...';

    // Show download progress dialog
    _showDownloadProgressDialog();

    try {
      final downloadResult = await _core.downloadApk(
        versionInfo.apkUrl,
        versionInfo.displayVersion,
        onProgress: (progress) {
          downloadProgress.value = progress.progress;
          downloadStatus.value = progress.status;
        },
      );

      switch (downloadResult) {
        case DownloadSuccess(filePath: final path):
          downloadStatus.value = 'Opening installer...';
          await Future.delayed(const Duration(seconds: 1));

          final installResult = await _core.installApk(path);

          switch (installResult) {
            case InstallSuccess():
              downloadStatus.value = 'Installation dialog opened. Please follow the system prompts.';
              await Future.delayed(const Duration(seconds: 3));
              _closeDialog();
            case InstallManualRequired(filePath: final file):
              _closeDialog();
              _showManualInstallDialog(file);
            case InstallError(message: final msg):
              downloadStatus.value = 'Error: $msg';
              await Future.delayed(const Duration(seconds: 2));
              _closeDialog();
            case InstallPermissionDenied():
              downloadStatus.value = 'Installation permission denied';
              await Future.delayed(const Duration(seconds: 2));
              _closeDialog();
          }

        case DownloadError(message: final msg):
          downloadStatus.value = 'Error: $msg';
          _showErrorSnackbar('Download Failed', 'Could not download update. Please try again.');
          await Future.delayed(const Duration(seconds: 2));
          _closeDialog();

        case DownloadCancelled():
          _closeDialog();
      }
    } finally {
      isDownloading.value = false;
    }
  }

  /// Cancel an ongoing download
  void cancelDownload() {
    _core.cancelDownload();
    isDownloading.value = false;
  }

  /// Clean up downloaded APK files
  Future<void> cleanupDownloads() => _core.cleanupDownloads();

  // ---- UI Methods (use callbacks if provided, otherwise default GetX dialogs) ----

  void _showDisabledSnackbar() {
    if (uiCallbacks?.onShowDisabledMessage != null) {
      uiCallbacks!.onShowDisabledMessage!();
      return;
    }

    Get.snackbar(
      'Updates Disabled',
      'Version updates are disabled',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _showNoUpdateSnackbar() {
    if (uiCallbacks?.onShowNoUpdateMessage != null) {
      uiCallbacks!.onShowNoUpdateMessage!();
      return;
    }

    Get.snackbar(
      'No Updates',
      'You are using the latest version',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _showErrorSnackbar(String title, String message) {
    if (uiCallbacks?.onShowError != null) {
      uiCallbacks!.onShowError!(title, message);
      return;
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withValues(alpha: 0.9),
      colorText: Colors.white,
    );
  }

  void _showUpdateAvailableUI(VersionInfo info) {
    if (uiCallbacks?.onShowUpdateAvailable != null) {
      uiCallbacks!.onShowUpdateAvailable!(info, () => _showDownloadConfirmation(info));
      return;
    }

    Get.snackbar(
      'Update Available',
      'Version ${info.displayVersion} is available. Tap to download and install.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.blue.withValues(alpha: 0.95),
      colorText: Colors.white,
      duration: const Duration(seconds: 10),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.system_update, color: Colors.white, size: 28),
      mainButton: TextButton(
        onPressed: () {
          Get.back();
          _showDownloadConfirmation(info);
        },
        child: const Text(
          'UPDATE',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: (_) {
        Get.back();
        _showDownloadConfirmation(info);
      },
    );
  }

  void _showDownloadConfirmation(VersionInfo info) {
    if (uiCallbacks?.onShowDownloadConfirmation != null) {
      uiCallbacks!.onShowDownloadConfirmation!(info, () => downloadAndInstall(info));
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Download Update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Do you want to download and install version ${info.displayVersion}?'),
            if (info.releaseNotes != null) ...[
              const SizedBox(height: 16),
              const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(info.releaseNotes!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              downloadAndInstall(info);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showPermissionDialog() async {
    if (uiCallbacks?.onShowPermissionDialog != null) {
      return await uiCallbacks!.onShowPermissionDialog!();
    }

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'This app needs permission to install updates. '
          'You will be redirected to settings where you need to enable '
          '"Install unknown apps" for this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showPermissionDeniedSnackbar() {
    if (uiCallbacks?.onShowPermissionDenied != null) {
      uiCallbacks!.onShowPermissionDenied!();
      return;
    }

    Get.snackbar(
      'Permission Denied',
      'Please enable "Install unknown apps" for this app in settings',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      mainButton: TextButton(
        onPressed: () => openAppSettings(),
        child: const Text('SETTINGS', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showDownloadProgressDialog() {
    if (uiCallbacks?.buildDownloadProgressDialog != null) {
      Get.dialog(
        uiCallbacks!.buildDownloadProgressDialog!(
          downloadProgress,
          downloadStatus,
          isDownloading,
        ),
        barrierDismissible: false,
      );
      return;
    }

    Get.dialog(
      PopScope(
        canPop: false,
        child: Obx(
          () => AlertDialog(
            title: const Text('Downloading Update'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(downloadStatus.value),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: downloadProgress.value > 0 ? downloadProgress.value : null,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 8),
                Text('${(downloadProgress.value * 100).toStringAsFixed(0)}%'),
              ],
            ),
            actions: isDownloading.value
                ? null
                : [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Close'),
                    ),
                  ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showManualInstallDialog(String filePath) {
    if (uiCallbacks?.onShowManualInstallRequired != null) {
      uiCallbacks!.onShowManualInstallRequired!(filePath);
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Manual Installation Required'),
        content: Text(
          'The APK has been downloaded to:\n$filePath\n\n'
          'Please install it manually using your file manager.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _closeDialog() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  @override
  void onClose() {
    _core.dispose();
    super.onClose();
  }
}

/// Callbacks for customizing the UI of the auto-updater.
///
/// Provide these callbacks to use your own dialogs and snackbars
/// instead of the default GetX-based ones.
class AutoUpdaterUICallbacks {
  /// Called when updates are disabled
  final VoidCallback? onShowDisabledMessage;

  /// Called when no update is available
  final VoidCallback? onShowNoUpdateMessage;

  /// Called when an error occurs
  final void Function(String title, String message)? onShowError;

  /// Called when an update is available.
  /// [onDownload] should be called to start the download.
  final void Function(VersionInfo info, VoidCallback onDownload)? onShowUpdateAvailable;

  /// Called to confirm download.
  /// [onConfirm] should be called to proceed with download.
  final void Function(VersionInfo info, VoidCallback onConfirm)? onShowDownloadConfirmation;

  /// Called to show permission dialog.
  /// Return true to proceed with permission request.
  final Future<bool> Function()? onShowPermissionDialog;

  /// Called when permission is denied
  final VoidCallback? onShowPermissionDenied;

  /// Called when manual installation is required
  final void Function(String filePath)? onShowManualInstallRequired;

  /// Build a custom download progress dialog.
  /// The returned widget will be shown in a dialog.
  final Widget Function(
    RxDouble progress,
    RxString status,
    RxBool isDownloading,
  )? buildDownloadProgressDialog;

  const AutoUpdaterUICallbacks({
    this.onShowDisabledMessage,
    this.onShowNoUpdateMessage,
    this.onShowError,
    this.onShowUpdateAvailable,
    this.onShowDownloadConfirmation,
    this.onShowPermissionDialog,
    this.onShowPermissionDenied,
    this.onShowManualInstallRequired,
    this.buildDownloadProgressDialog,
  });
}
