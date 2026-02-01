import 'package:flutter/material.dart';

import '../config.dart';
import '../core_service.dart';

/// Standalone auto-updater service using Flutter's built-in ValueNotifier.
///
/// This adapter wraps [AutoUpdaterCore] and provides reactive state management
/// without any external dependencies like GetX, Provider, or Riverpod.
///
/// Usage:
/// ```dart
/// // Create the service
/// final updater = AutoUpdaterStandalone(
///   config: AutoUpdaterConfig(
///     baseUrl: 'https://your-server.com',
///     appId: 'com.example.app',
///   ),
/// );
///
/// // Initialize (call once at app startup)
/// await updater.initialize();
///
/// // Listen to state changes
/// updater.isDownloading.addListener(() {
///   print('Downloading: ${updater.isDownloading.value}');
/// });
///
/// // Or use ValueListenableBuilder in your widgets
/// ValueListenableBuilder<bool>(
///   valueListenable: updater.isDownloading,
///   builder: (context, isDownloading, child) {
///     return isDownloading ? CircularProgressIndicator() : Container();
///   },
/// )
/// ```
class AutoUpdaterStandalone {
  final AutoUpdaterCore _core;
  final AutoUpdaterStandaloneUI? ui;

  /// Reactive state: whether currently checking for updates
  final ValueNotifier<bool> isCheckingForUpdate = ValueNotifier(false);

  /// Reactive state: whether currently downloading
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);

  /// Reactive state: download progress (0.0 to 1.0)
  final ValueNotifier<double> downloadProgress = ValueNotifier(0.0);

  /// Reactive state: download status message
  final ValueNotifier<String> downloadStatus = ValueNotifier('');

  /// Reactive state: last update check result
  final ValueNotifier<UpdateCheckResult?> lastCheckResult = ValueNotifier(null);

  AutoUpdaterStandalone({
    required AutoUpdaterConfig config,
    this.ui,
  }) : _core = AutoUpdaterCore(config: config);

  /// Access to the underlying configuration
  AutoUpdaterConfig get config => _core.config;

  /// Access to the core service (for debugging)
  AutoUpdaterCore get core => _core;

  /// Whether the service has been initialized
  bool get isInitialized => _core.isInitialized;

  /// Current app version info
  CurrentVersionInfo? get currentVersion => _core.currentVersion;

  /// Device architecture (Android only)
  String? get deviceArchitecture => _core.deviceArchitecture;

  /// Initialize the service. Must be called before using other methods.
  Future<void> initialize() async {
    await _core.initialize();

    config.log(
      'AutoUpdaterStandalone initialized - '
      'checkOnStartup: ${config.checkOnStartup}, '
      'isDisabled: ${config.isDisabled}',
    );

    if (config.checkOnStartup && !config.isDisabled) {
      config.log('Scheduling update check after ${config.startupDelay.inSeconds} seconds');
      Future.delayed(config.startupDelay, () => checkForUpdate(silent: true));
    }
  }

  /// Check for updates.
  ///
  /// [silent] - If true, no UI feedback is shown for "no update" or errors.
  /// [context] - Required for showing dialogs if [ui] callbacks use it.
  Future<UpdateCheckResult> checkForUpdate({
    bool silent = true,
    BuildContext? context,
  }) async {
    if (config.isDisabled) {
      config.log('Update check disabled');
      if (!silent) {
        ui?.onShowDisabledMessage?.call(context);
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
          ui?.onShowUpdateAvailable?.call(
            context,
            info,
            () => downloadAndInstall(info, context: context),
          );
        case NoUpdateAvailable():
          if (!silent) {
            ui?.onShowNoUpdateMessage?.call(context);
          }
        case UpdateCheckError(message: final msg):
          if (!silent) {
            ui?.onShowError?.call(context, 'Update Check Failed', msg);
          }
        case UpdateCheckDisabled():
          if (!silent) {
            ui?.onShowDisabledMessage?.call(context);
          }
      }

      return result;
    } finally {
      isCheckingForUpdate.value = false;
    }
  }

  /// Start the download and installation flow for a version.
  Future<void> downloadAndInstall(
    VersionInfo versionInfo, {
    BuildContext? context,
  }) async {
    if (isDownloading.value) return;

    // Request permissions
    final hasPermission = await _core.requestInstallPermissions(
      onPermissionDialogRequired: () async {
        if (ui?.onShowPermissionDialog != null) {
          return await ui!.onShowPermissionDialog!(context);
        }
        return true; // Proceed if no UI handler
      },
    );

    if (!hasPermission) {
      ui?.onShowPermissionDenied?.call(context);
      return;
    }

    isDownloading.value = true;
    downloadProgress.value = 0.0;
    downloadStatus.value = 'Starting download...';

    // Show download progress UI
    final dismissProgress = ui?.onShowDownloadProgress?.call(
      context,
      downloadProgress,
      downloadStatus,
      isDownloading,
    );

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
              downloadStatus.value = 'Installation dialog opened.';
              await Future.delayed(const Duration(seconds: 2));
              dismissProgress?.call();
            case InstallManualRequired(filePath: final file):
              dismissProgress?.call();
              ui?.onShowManualInstallRequired?.call(context, file);
            case InstallError(message: final msg):
              downloadStatus.value = 'Error: $msg';
              await Future.delayed(const Duration(seconds: 2));
              dismissProgress?.call();
            case InstallPermissionDenied():
              downloadStatus.value = 'Permission denied';
              await Future.delayed(const Duration(seconds: 2));
              dismissProgress?.call();
          }

        case DownloadError(message: final msg):
          downloadStatus.value = 'Error: $msg';
          ui?.onShowError?.call(context, 'Download Failed', msg);
          await Future.delayed(const Duration(seconds: 2));
          dismissProgress?.call();

        case DownloadCancelled():
          dismissProgress?.call();
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

  /// Dispose of resources. Call when the service is no longer needed.
  void dispose() {
    _core.dispose();
    isCheckingForUpdate.dispose();
    isDownloading.dispose();
    downloadProgress.dispose();
    downloadStatus.dispose();
    lastCheckResult.dispose();
  }
}

/// UI callbacks for the standalone auto-updater.
///
/// All callbacks are optional. If not provided, the corresponding UI
/// will not be shown (silent mode).
///
/// Example with Flutter's built-in dialogs:
/// ```dart
/// AutoUpdaterStandaloneUI(
///   onShowUpdateAvailable: (context, info, onDownload) {
///     showDialog(
///       context: context!,
///       builder: (ctx) => AlertDialog(
///         title: Text('Update Available'),
///         content: Text('Version ${info.displayVersion} is available'),
///         actions: [
///           TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Later')),
///           ElevatedButton(
///             onPressed: () {
///               Navigator.pop(ctx);
///               onDownload();
///             },
///             child: Text('Update'),
///           ),
///         ],
///       ),
///     );
///   },
/// )
/// ```
class AutoUpdaterStandaloneUI {
  /// Called when updates are disabled
  final void Function(BuildContext? context)? onShowDisabledMessage;

  /// Called when no update is available
  final void Function(BuildContext? context)? onShowNoUpdateMessage;

  /// Called when an error occurs
  final void Function(BuildContext? context, String title, String message)? onShowError;

  /// Called when an update is available.
  /// [onDownload] should be called to start the download.
  final void Function(
    BuildContext? context,
    VersionInfo info,
    VoidCallback onDownload,
  )? onShowUpdateAvailable;

  /// Called to show permission dialog.
  /// Return true to proceed with permission request.
  final Future<bool> Function(BuildContext? context)? onShowPermissionDialog;

  /// Called when permission is denied
  final void Function(BuildContext? context)? onShowPermissionDenied;

  /// Called when manual installation is required
  final void Function(BuildContext? context, String filePath)? onShowManualInstallRequired;

  /// Called to show download progress.
  /// Returns a callback to dismiss the progress UI.
  final VoidCallback? Function(
    BuildContext? context,
    ValueNotifier<double> progress,
    ValueNotifier<String> status,
    ValueNotifier<bool> isDownloading,
  )? onShowDownloadProgress;

  const AutoUpdaterStandaloneUI({
    this.onShowDisabledMessage,
    this.onShowNoUpdateMessage,
    this.onShowError,
    this.onShowUpdateAvailable,
    this.onShowPermissionDialog,
    this.onShowPermissionDenied,
    this.onShowManualInstallRequired,
    this.onShowDownloadProgress,
  });
}

/// Customizable strings for the auto-updater UI.
///
/// Override specific strings to localize the UI:
/// ```dart
/// AutoUpdaterStrings(
///   updateAvailable: 'Aktualizácia dostupná',
///   download: 'Stiahnuť',
///   later: 'Neskôr',
/// )
/// ```
class AutoUpdaterStrings {
  final String updateAvailable;
  final String noUpdateAvailable;
  final String downloading;
  final String download;
  final String later;
  final String cancel;
  final String close;
  final String ok;
  final String version;
  final String releaseNotes;
  final String permissionRequired;
  final String permissionMessage;
  final String permissionDenied;
  final String openSettings;
  final String manualInstallRequired;
  final String updatesDisabled;
  final String checkFailed;
  final String downloadFailed;

  const AutoUpdaterStrings({
    this.updateAvailable = 'Update Available',
    this.noUpdateAvailable = 'You are using the latest version',
    this.downloading = 'Downloading Update',
    this.download = 'Download',
    this.later = 'Later',
    this.cancel = 'Cancel',
    this.close = 'Close',
    this.ok = 'OK',
    this.version = 'Version',
    this.releaseNotes = 'Release Notes:',
    this.permissionRequired = 'Permission Required',
    this.permissionMessage = 'This app needs permission to install updates. '
        'You will be redirected to settings to enable "Install unknown apps".',
    this.permissionDenied = 'Permission denied. Please enable "Install unknown apps" in settings.',
    this.openSettings = 'Open Settings',
    this.manualInstallRequired = 'Manual Installation Required',
    this.updatesDisabled = 'Updates are disabled',
    this.checkFailed = 'Update Check Failed',
    this.downloadFailed = 'Download Failed',
  });
}

/// Pre-built UI handlers using Flutter's built-in dialogs and snackbars.
///
/// Usage:
/// ```dart
/// final updater = AutoUpdaterStandalone(
///   config: myConfig,
///   ui: AutoUpdaterDefaultUI.create(
///     primaryColor: Colors.blue,
///     strings: AutoUpdaterStrings(
///       updateAvailable: 'Aktualizácia dostupná',
///       download: 'Stiahnuť',
///     ),
///   ),
/// );
/// ```
class AutoUpdaterDefaultUI {
  /// Creates a default UI configuration using Flutter's built-in widgets.
  ///
  /// [primaryColor] - Color for buttons and progress indicators
  /// [strings] - Custom strings for localization
  /// [scaffoldMessengerKey] - GlobalKey for showing snackbars (optional)
  /// [navigatorKey] - GlobalKey for showing dialogs (optional)
  static AutoUpdaterStandaloneUI create({
    Color primaryColor = Colors.blue,
    AutoUpdaterStrings strings = const AutoUpdaterStrings(),
    GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    void showSnackBar(BuildContext? context, String message, Color bgColor) {
      if (scaffoldMessengerKey?.currentState != null) {
        scaffoldMessengerKey!.currentState!.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
          ),
        );
      } else if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
          ),
        );
      }
    }

    Future<T?> showDialogHelper<T>(
      BuildContext? context,
      Widget Function(BuildContext) builder,
    ) {
      if (navigatorKey?.currentState != null) {
        return showDialog<T>(
          context: navigatorKey!.currentState!.context,
          builder: builder,
        );
      } else if (context != null) {
        return showDialog<T>(context: context, builder: builder);
      }
      return Future.value(null);
    }

    return AutoUpdaterStandaloneUI(
      onShowDisabledMessage: (context) {
        showSnackBar(context, strings.updatesDisabled, Colors.orange);
      },

      onShowNoUpdateMessage: (context) {
        showSnackBar(context, strings.noUpdateAvailable, Colors.green);
      },

      onShowError: (context, title, message) {
        showSnackBar(context, '$title: $message', Colors.red);
      },

      onShowUpdateAvailable: (context, info, onDownload) {
        showDialogHelper(
          context,
          (ctx) => AlertDialog(
            title: Text(strings.updateAvailable),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${strings.version} ${info.displayVersion}'),
                if (info.releaseNotes != null) ...[
                  const SizedBox(height: 16),
                  Text(strings.releaseNotes, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(info.releaseNotes!, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(strings.later),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onDownload();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(strings.download),
              ),
            ],
          ),
        );
      },

      onShowPermissionDialog: (context) async {
        final result = await showDialogHelper<bool>(
          context,
          (ctx) => AlertDialog(
            title: Text(strings.permissionRequired),
            content: Text(strings.permissionMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(strings.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(strings.openSettings),
              ),
            ],
          ),
        );
        return result ?? false;
      },

      onShowPermissionDenied: (context) {
        showSnackBar(context, strings.permissionDenied, Colors.red);
      },

      onShowManualInstallRequired: (context, filePath) {
        showDialogHelper(
          context,
          (ctx) => AlertDialog(
            title: Text(strings.manualInstallRequired),
            content: Text(
              'The APK has been downloaded to:\n$filePath\n\n'
              'Please install it manually using your file manager.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(strings.ok),
              ),
            ],
          ),
        );
      },

      onShowDownloadProgress: (context, progress, status, isDownloading) {
        // Store the dialog's navigator context
        BuildContext? dialogContext;

        showDialogHelper(
          context,
          (ctx) {
            dialogContext = ctx;
            return PopScope(
              canPop: false,
              child: _DownloadProgressDialog(
                progress: progress,
                status: status,
                isDownloading: isDownloading,
                primaryColor: primaryColor,
                title: strings.downloading,
                closeText: strings.close,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            );
          },
        );

        // Return dismiss callback
        return () {
          if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
            Navigator.of(dialogContext!).pop();
          }
        };
      },
    );
  }
}

/// Download progress dialog with proper listener management.
class _DownloadProgressDialog extends StatefulWidget {
  final ValueNotifier<double> progress;
  final ValueNotifier<String> status;
  final ValueNotifier<bool> isDownloading;
  final Color primaryColor;
  final String title;
  final String closeText;
  final VoidCallback onClose;

  const _DownloadProgressDialog({
    required this.progress,
    required this.status,
    required this.isDownloading,
    required this.primaryColor,
    required this.title,
    required this.closeText,
    required this.onClose,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onUpdate);
    widget.status.addListener(_onUpdate);
    widget.isDownloading.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onUpdate);
    widget.status.removeListener(_onUpdate);
    widget.isDownloading.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.status.value),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: widget.progress.value > 0 ? widget.progress.value : null,
            minHeight: 6,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
          ),
          const SizedBox(height: 8),
          Text('${(widget.progress.value * 100).toStringAsFixed(0)}%'),
        ],
      ),
      actions: widget.isDownloading.value
          ? null
          : [
              TextButton(
                onPressed: widget.onClose,
                child: Text(widget.closeText),
              ),
            ],
    );
  }
}
