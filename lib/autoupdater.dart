/// A fully configurable auto-update plugin for Flutter apps.
///
/// This plugin provides automatic update checking, APK downloading, and
/// installation support for Android apps. It's framework-agnostic and works
/// with any state management solution (GetX, Provider, Bloc, Riverpod, or none).
///
/// ## Simple Usage (Recommended)
///
/// ```dart
/// import 'package:releasehub_updater/autoupdater.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Initialize with ReleaseHub backend
///   await AutoUpdater.init(
///     baseUrl: 'https://app.v2.sk',
///     projectSlug: 'my-app',
///     channel: 'stable',
///   );
///
///   runApp(MyApp());
/// }
///
/// // Manual check (e.g., from settings screen)
/// AutoUpdater.checkForUpdates();
/// ```
///
/// ## Advanced Usage
///
/// For more control, use [AutoUpdaterStandalone] directly:
///
/// ```dart
/// import 'package:releasehub_updater/autoupdater_standalone.dart';
///
/// final updater = AutoUpdaterStandalone(
///   config: AutoUpdaterConfig.releaseHub(
///     baseUrl: 'https://app.v2.sk',
///     projectSlug: 'my-app',
///   ),
///   ui: AutoUpdaterDefaultUI.create(primaryColor: Colors.blue),
/// );
/// await updater.initialize();
/// ```
///
/// ## Features
///
/// - Automatic update checking on startup (configurable)
/// - Manual update checking
/// - APK download with progress tracking
/// - Automatic installation triggering
/// - Permission handling for Android
/// - Built-in UI dialogs (no callbacks needed)
/// - Architecture-aware APK selection
library;

import 'package:flutter/material.dart';

import 'src/adapters/standalone_adapter.dart';
import 'src/config.dart';

// Core exports
export 'src/config.dart';
export 'src/core_service.dart';

// UI widgets
export 'src/ui/download_progress_widget.dart';

// Standalone adapter (framework-agnostic)
export 'src/adapters/standalone_adapter.dart';

/// Simple static API for the auto-updater.
///
/// This provides the easiest way to use the plugin with sensible defaults
/// and built-in UI. No callbacks or adapters needed.
///
/// ```dart
/// // Initialize once at app startup
/// await AutoUpdater.init(
///   baseUrl: 'https://app.v2.sk',
///   projectSlug: 'my-app',
///   channel: 'stable',
/// );
///
/// // Manual check from settings
/// AutoUpdater.checkForUpdates();
/// ```
class AutoUpdater {
  static AutoUpdaterStandalone? _instance;
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  AutoUpdater._();

  /// Global navigator key for showing dialogs.
  ///
  /// Use this in your MaterialApp:
  /// ```dart
  /// MaterialApp(
  ///   navigatorKey: AutoUpdater.navigatorKey,
  ///   // ...
  /// )
  /// ```
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// Global scaffold messenger key for showing snackbars.
  ///
  /// Use this in your MaterialApp:
  /// ```dart
  /// MaterialApp(
  ///   scaffoldMessengerKey: AutoUpdater.scaffoldMessengerKey,
  ///   // ...
  /// )
  /// ```
  static GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey => _scaffoldKey;

  /// Whether the auto-updater has been initialized.
  static bool get isInitialized => _instance?.isInitialized ?? false;

  /// The underlying service instance (for advanced usage).
  static AutoUpdaterStandalone? get instance => _instance;

  /// Initialize the auto-updater with ReleaseHub backend.
  ///
  /// Call this once at app startup, typically in your `main()` function.
  ///
  /// [baseUrl] - The ReleaseHub server URL (e.g., 'https://app.v2.sk')
  /// [projectSlug] - Your project's slug/identifier
  /// [channel] - Release channel (default: 'stable')
  /// [checkOnStartup] - Whether to check for updates on init (default: true)
  /// [startupDelay] - Delay before startup check (default: 3 seconds)
  /// [primaryColor] - Color for UI elements (default: teal)
  /// [strings] - Custom strings for localization
  ///
  /// Example:
  /// ```dart
  /// await AutoUpdater.init(
  ///   baseUrl: 'https://app.v2.sk',
  ///   projectSlug: 'my-app',
  ///   channel: 'stable',
  /// );
  /// ```
  ///
  /// With localization:
  /// ```dart
  /// await AutoUpdater.init(
  ///   baseUrl: 'https://app.v2.sk',
  ///   projectSlug: 'my-app',
  ///   strings: AutoUpdaterStrings(
  ///     updateAvailable: 'Aktualizácia dostupná',
  ///     download: 'Stiahnuť',
  ///     later: 'Neskôr',
  ///   ),
  /// );
  /// ```
  static Future<void> init({
    required String baseUrl,
    required String projectSlug,
    String channel = 'stable',
    bool checkOnStartup = true,
    Duration startupDelay = const Duration(seconds: 3),
    Color primaryColor = const Color(0xFF0D9488), // Teal
    AutoUpdaterStrings strings = const AutoUpdaterStrings(),
  }) async {
    if (_instance != null) {
      debugPrint('[AutoUpdater] Already initialized');
      return;
    }

    final config = AutoUpdaterConfig.releaseHub(
      baseUrl: baseUrl,
      projectSlug: projectSlug,
      channel: channel,
      checkOnStartup: checkOnStartup,
      startupDelay: startupDelay,
    );

    _instance = AutoUpdaterStandalone(
      config: config,
      ui: AutoUpdaterDefaultUI.create(
        primaryColor: primaryColor,
        strings: strings,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _scaffoldKey,
      ),
    );

    await _instance!.initialize();
    debugPrint('[AutoUpdater] Initialized for $projectSlug on $baseUrl');
  }

  /// Initialize with a custom configuration.
  ///
  /// For advanced use cases where you need full control over the config.
  ///
  /// Example:
  /// ```dart
  /// await AutoUpdater.initWithConfig(
  ///   config: AutoUpdaterConfig(
  ///     baseUrl: 'https://my-server.com',
  ///     appId: 'com.example.app',
  ///     versionPath: 'api/version',
  ///     environment: 'production',
  ///   ),
  /// );
  /// ```
  static Future<void> initWithConfig({
    required AutoUpdaterConfig config,
    Color primaryColor = const Color(0xFF0D9488),
  }) async {
    if (_instance != null) {
      debugPrint('[AutoUpdater] Already initialized');
      return;
    }

    _instance = AutoUpdaterStandalone(
      config: config,
      ui: AutoUpdaterDefaultUI.create(
        primaryColor: primaryColor,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _scaffoldKey,
      ),
    );

    await _instance!.initialize();
    debugPrint('[AutoUpdater] Initialized with custom config');
  }

  /// Manually check for updates.
  ///
  /// Shows UI feedback (dialogs/snackbars) for the result.
  /// Call this from your settings screen's "Check for updates" button.
  ///
  /// Example:
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => AutoUpdater.checkForUpdates(),
  ///   child: Text('Check for Updates'),
  /// )
  /// ```
  static Future<void> checkForUpdates() async {
    if (_instance == null) {
      debugPrint('[AutoUpdater] Not initialized. Call init() first.');
      return;
    }

    if (_navigatorKey.currentState == null) {
      debugPrint('[AutoUpdater] Navigator not ready. Make sure navigatorKey is attached to MaterialApp.');
      return;
    }

    await _instance!.checkForUpdate(silent: false);
  }

  /// Check for updates silently (no UI feedback if no update).
  ///
  /// Only shows UI if an update is available.
  static Future<void> checkForUpdatesSilent() async {
    if (_instance == null) {
      debugPrint('[AutoUpdater] Not initialized. Call init() first.');
      return;
    }

    // For silent checks, we wait for navigator to be ready
    // This handles the case where startup check runs before app is fully initialized
    if (_navigatorKey.currentState == null) {
      debugPrint('[AutoUpdater] Navigator not ready yet, will retry in 1 second...');
      await Future.delayed(const Duration(seconds: 1));
      if (_navigatorKey.currentState == null) {
        debugPrint('[AutoUpdater] Navigator still not ready. Skipping silent check.');
        return;
      }
    }

    await _instance!.checkForUpdate(silent: true);
  }

  /// Dispose of resources.
  ///
  /// Call this when the app is being disposed (rarely needed).
  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }

  /// Get debug info for troubleshooting update issues.
  ///
  /// Returns a formatted string with version info, URLs, and configuration.
  /// Useful for debugging when updates aren't detected correctly.
  static String getDebugInfo() {
    if (_instance == null) {
      return 'AutoUpdater not initialized';
    }
    return _instance!.core.getDebugInfo();
  }

  /// Show a debug dialog with version check info.
  ///
  /// This will check for updates and show detailed debug info in a dialog.
  static Future<void> showDebugDialog() async {
    if (_instance == null) {
      debugPrint('[AutoUpdater] Not initialized');
      return;
    }

    final context = _navigatorKey.currentState?.context;
    if (context == null) {
      debugPrint('[AutoUpdater] No context available');
      return;
    }

    final debugInfo = getDebugInfo();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AutoUpdater Debug'),
        content: SingleChildScrollView(
          child: SelectableText(
            debugInfo,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              checkForUpdates();
            },
            child: const Text('Check Now'),
          ),
        ],
      ),
    );
  }
}
