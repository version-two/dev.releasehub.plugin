/// GetX adapter for the autoupdater plugin.
///
/// This export includes the GetX-specific [AutoUpdaterGetxService] which
/// provides reactive state management and integrates with GetX navigation.
///
/// ## Usage
///
/// ```dart
/// import 'package:releasehub_updater/autoupdater_getx.dart';
///
/// // Register the service (typically in your main.dart or initServices)
/// Get.put(AutoUpdaterGetxService(
///   config: AutoUpdaterConfig(
///     baseUrl: 'https://your-server.com',
///     appId: 'com.example.app',
///     environment: 'prod',
///     checkOnStartup: true,
///   ),
/// ), permanent: true);
///
/// // Manual check from a widget
/// final updater = Get.find<AutoUpdaterGetxService>();
/// await updater.checkForUpdate(silent: false);
///
/// // Use reactive state in your UI
/// Obx(() => updater.isDownloading.value
///   ? CircularProgressIndicator()
///   : YourWidget()
/// )
/// ```
///
/// ## Custom UI
///
/// You can customize all dialogs and snackbars by providing [AutoUpdaterUICallbacks]:
///
/// ```dart
/// Get.put(AutoUpdaterGetxService(
///   config: myConfig,
///   uiCallbacks: AutoUpdaterUICallbacks(
///     onShowUpdateAvailable: (info, onDownload) {
///       // Show your custom dialog
///       showMyCustomDialog(info, onDownload);
///     },
///     onShowError: (title, message) {
///       // Show your custom error UI
///       showMyErrorSnackbar(title, message);
///     },
///   ),
/// ));
/// ```
library;

// Re-export core
export 'autoupdater.dart';

// GetX adapter
export 'src/adapters/getx_adapter.dart';
