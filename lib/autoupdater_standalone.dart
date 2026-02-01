/// Standalone adapter for the autoupdater plugin.
///
/// This export includes [AutoUpdaterStandalone] which uses Flutter's built-in
/// [ValueNotifier] for reactive state management. No external dependencies required.
///
/// ## Usage
///
/// ```dart
/// import 'package:releasehub_updater/autoupdater_standalone.dart';
///
/// // Create the service with optional UI handlers
/// final updater = AutoUpdaterStandalone(
///   config: AutoUpdaterConfig(
///     baseUrl: 'https://your-server.com',
///     appId: 'com.example.app',
///     environment: 'prod',
///     checkOnStartup: true,
///   ),
///   ui: AutoUpdaterDefaultUI.create(
///     primaryColor: Colors.blue,
///   ),
/// );
///
/// // Initialize (call once at app startup)
/// await updater.initialize();
///
/// // Manual check with context for dialogs
/// await updater.checkForUpdate(silent: false, context: context);
/// ```
///
/// ## Using with ValueListenableBuilder
///
/// ```dart
/// ValueListenableBuilder<bool>(
///   valueListenable: updater.isCheckingForUpdate,
///   builder: (context, isChecking, child) {
///     return isChecking
///       ? CircularProgressIndicator()
///       : ElevatedButton(
///           onPressed: () => updater.checkForUpdate(
///             silent: false,
///             context: context,
///           ),
///           child: Text('Check for Updates'),
///         );
///   },
/// )
/// ```
///
/// ## Custom UI Handlers
///
/// ```dart
/// final updater = AutoUpdaterStandalone(
///   config: myConfig,
///   ui: AutoUpdaterStandaloneUI(
///     onShowUpdateAvailable: (context, info, onDownload) {
///       // Show your custom dialog
///       showMyCustomDialog(context!, info, onDownload);
///     },
///     onShowError: (context, title, message) {
///       // Show your custom error UI
///       MyToast.showError('$title: $message');
///     },
///     onShowDownloadProgress: (context, progress, status, isDownloading) {
///       // Show custom progress UI
///       showMyProgressOverlay(progress, status);
///       // Return a callback to dismiss it
///       return () => hideMyProgressOverlay();
///     },
///   ),
/// );
/// ```
///
/// ## Integration with Provider/Riverpod
///
/// Since [AutoUpdaterStandalone] uses [ValueNotifier], it integrates seamlessly
/// with Provider or Riverpod:
///
/// ```dart
/// // Provider
/// Provider<AutoUpdaterStandalone>(
///   create: (_) => AutoUpdaterStandalone(config: myConfig)..initialize(),
///   dispose: (_, updater) => updater.dispose(),
/// )
///
/// // Riverpod
/// final autoUpdaterProvider = Provider((ref) {
///   final updater = AutoUpdaterStandalone(config: myConfig);
///   updater.initialize();
///   ref.onDispose(() => updater.dispose());
///   return updater;
/// });
/// ```
library;

// Re-export core
export 'autoupdater.dart';

// Standalone adapter
export 'src/adapters/standalone_adapter.dart';
