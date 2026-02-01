# Auto-Updater

[![pub package](https://img.shields.io/pub/v/releasehub_updater.svg)](https://pub.dev/packages/releasehub_updater)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A fully configurable auto-update plugin for Flutter Android apps. Supports checking for updates, downloading APKs, and triggering installation.

## Requirements

This plugin requires a **[ReleaseHub](https://releasehub.dev)** backend to serve version information and APK files:

- **Hosted**: Use [https://releasehub.dev](https://releasehub.dev) - managed service by Version Two
- **Self-hosted**: Deploy your own ReleaseHub instance on your server

> **Important:** ReleaseHub (either hosted at releasehub.dev or self-hosted) is **required** for this plugin to function. The plugin communicates with ReleaseHub's API to check for updates and download files.

## What is ReleaseHub?

[ReleaseHub](https://releasehub.dev) is a modern, secure web application for managing software releases across multiple platforms. While ReleaseHub supports many platforms (APK, AAB, EXE, MSI, DMG, AppImage, DEB, ZIP, etc.), this Flutter plugin specifically handles **Android APK** auto-updates.

### ReleaseHub Features

- **Multi-Platform Support**: Android (APK, AAB), Windows (EXE, MSI), macOS (DMG), Linux (AppImage, DEB), Web (ZIP)
- **Release Channels**: Custom channels per project (Stable, Beta, Alpha, etc.)
- **Version Comparison**: Build number first OR semantic versioning only
- **Architecture Detection**: Auto-detect from filename + manual override + universal builds
- **Changelogs**: Full Markdown support
- **Force Updates**: Per-version flag for critical updates
- **Download Authentication Options**:
  - **Public** - No authentication required
  - **API Key** - Requires API key in headers
  - **Password Protected** - Requires password
  - **Access Codes** - Single or multi-use codes
  - **Invite Links** - Time-limited sharing links

## Platform Support

| Android | iOS | Web | macOS | Windows | Linux |
|:-------:|:---:|:---:|:-----:|:-------:|:-----:|
|    ✅    |  ❌  |  ❌  |   ❌   |    ❌    |   ❌   |

> **Important:** This plugin only supports **Android**. The APK download and installation functionality is Android-specific. iOS, desktop, and web platforms are not supported by this plugin.

This plugin is designed for:
- Sideloaded Android apps
- Internal/enterprise Android apps
- Apps distributed outside the Google Play Store

## Features

- Automatic update checking on app startup (configurable)
- Manual update checking
- APK download with real-time progress tracking
- Automatic installation triggering via system installer
- Android permission handling (install packages, storage)
- Architecture-aware APK selection (arm64-v8a, armeabi-v7a, x86_64, x86)
- Build number normalization for split APK builds
- Support for public and API-authenticated projects
- Customizable UI callbacks for all dialogs and notifications
- Framework-agnostic core with multiple adapters:
  - **Standalone** - Uses Flutter's built-in `ValueNotifier` (no dependencies)
  - **GetX** - Uses GetX reactive state management
- Localization support

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  releasehub_updater: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### GetX Adapter (Optional)

If using the GetX adapter, ensure you have GetX in your dependencies:

```yaml
dependencies:
  get: ^4.6.6
```

## Android Configuration

### Required Permissions

Add to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Required for downloading updates -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Required for installing APKs -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />

    <!-- Required for Android 9 and below -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />

    <application ...>
        <!-- Your activities and other components -->
    </application>
</manifest>
```

### File Provider Configuration (Android 7+)

The `open_filex` package usually handles this automatically. If APK installation fails, add to your `AndroidManifest.xml` inside the `<application>` tag:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileProvider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

And create `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <external-files-path name="external_files_path" path="." />
    <cache-path name="cache" path="." />
</paths>
```

## ReleaseHub Setup

### Using Hosted ReleaseHub (releasehub.dev)

1. Create an account at [https://releasehub.dev](https://releasehub.dev)
2. Create a new project and note your **project slug**
3. Upload your APK builds with version information (manually or via [FLaunch CLI](#flaunch-cli-tool))
4. Configure project visibility:
   - **Public**: Anyone can check for updates (no authentication required)
   - **API Key**: Requires API key for update checks
   - **Password Protected**: Requires password
   - **Access Codes**: Single or multi-use codes

### Self-Hosting ReleaseHub

ReleaseHub can be self-hosted on your own infrastructure:

1. Deploy ReleaseHub to your server (PHP 8.3+, SQLite or MySQL)
2. Run `php artisan releasehub:setup` to create admin user and configure platforms
3. Configure your instance URL as the `baseUrl` in the plugin
4. Create projects and upload APK builds

See the [ReleaseHub documentation](https://releasehub.dev/docs) for detailed self-hosting instructions.

### FLaunch CLI Tool

For automated builds and uploads, use [FLaunch](https://releasehub.dev/flaunch) - a Rust CLI tool that streamlines your release workflow:

**Installation:**

| Platform | Method |
|----------|--------|
| **Windows** | Download installer (EXE/MSI) from [releasehub.dev/flaunch](https://releasehub.dev/flaunch) or run: `irm https://releasehub.dev/install.ps1 \| iex` |
| **macOS** | `curl -fsSL https://releasehub.dev/install \| sh` |
| **Linux** | `curl -fsSL https://releasehub.dev/install \| sh` |

**Usage:**

```bash
# Build and upload in one command
flaunch production -c stable
```

FLaunch handles version bumping, building, uploading to ReleaseHub, and Discord notifications.

## Project Visibility & Authentication

### Public Projects (No Authentication)

```dart
await AutoUpdater.init(
  baseUrl: 'https://releasehub.dev',  // or your self-hosted URL
  projectSlug: 'my-public-app',
  channel: 'stable',
);
```

### Private Projects (API Key Authentication)

```dart
await AutoUpdater.initWithConfig(
  config: AutoUpdaterConfig.releaseHub(
    baseUrl: 'https://releasehub.dev',
    projectSlug: 'my-private-app',
    channel: 'stable',
    httpHeaders: {
      'Authorization': 'Bearer YOUR_API_KEY',
    },
  ),
);
```

## Quick Start

### Simple Usage (Recommended)

The easiest way to use the plugin with built-in UI:

```dart
import 'package:releasehub_updater/autoupdater.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the auto-updater with ReleaseHub
  await AutoUpdater.init(
    baseUrl: 'https://releasehub.dev',  // or your self-hosted URL
    projectSlug: 'my-app',
    channel: 'stable',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Required for dialogs to work
      navigatorKey: AutoUpdater.navigatorKey,
      scaffoldMessengerKey: AutoUpdater.scaffoldMessengerKey,
      home: HomeScreen(),
    );
  }
}

// Manual check from settings screen
ElevatedButton(
  onPressed: () => AutoUpdater.checkForUpdates(),
  child: Text('Check for Updates'),
)

// Silent check (only shows UI if update available)
AutoUpdater.checkForUpdatesSilent();

// Check initialization status
if (AutoUpdater.isInitialized) {
  // Access underlying service for advanced usage
  final service = AutoUpdater.instance;
}

// Dispose when app closes (rarely needed)
AutoUpdater.dispose();
```

### Standalone Usage (No External Dependencies)

Uses Flutter's built-in `ValueNotifier` for reactive state:

```dart
import 'package:releasehub_updater/autoupdater_standalone.dart';

// Create the service
final updater = AutoUpdaterStandalone(
  config: AutoUpdaterConfig.releaseHub(
    baseUrl: 'https://releasehub.dev',
    projectSlug: 'my-app',
    channel: 'stable',
  ),
  ui: AutoUpdaterDefaultUI.create(
    primaryColor: Colors.blue,
  ),
);

// Initialize (call once at app startup)
await updater.initialize();

// Use ValueListenableBuilder for reactive UI
ValueListenableBuilder<bool>(
  valueListenable: updater.isCheckingForUpdate,
  builder: (context, isChecking, child) {
    return isChecking
      ? CircularProgressIndicator()
      : ElevatedButton(
          onPressed: () => updater.checkForUpdate(
            silent: false,
            context: context,
          ),
          child: Text('Check for Updates'),
        );
  },
)

// Don't forget to dispose when done
updater.dispose();
```

### GetX Usage

```dart
import 'package:releasehub_updater/autoupdater_getx.dart';

// Register the service
Get.put(
  AutoUpdaterGetxService(
    config: AutoUpdaterConfig.releaseHub(
      baseUrl: 'https://releasehub.dev',
      projectSlug: 'my-app',
      channel: 'stable',
    ),
  ),
  permanent: true,
);

// Use in widgets
final updater = Get.find<AutoUpdaterGetxService>();
Obx(() => updater.isCheckingForUpdate.value
  ? CircularProgressIndicator()
  : Text('Version: ${updater.currentVersion?.version}')
)
```

### Core Service (Maximum Control)

```dart
import 'package:releasehub_updater/autoupdater.dart';

final core = AutoUpdaterCore(
  config: AutoUpdaterConfig.releaseHub(
    baseUrl: 'https://releasehub.dev',
    projectSlug: 'my-app',
  ),
);

await core.initialize();

final result = await core.checkForUpdate();

switch (result) {
  case UpdateAvailable(versionInfo: final info):
    print('Update available: ${info.displayVersion}');
    // Download and install manually
    final downloadResult = await core.downloadApk(
      info.apkUrl,
      info.displayVersion,
      onProgress: (progress) => print(progress.formattedProgress),
    );
  case NoUpdateAvailable():
    print('Already on latest version');
  case UpdateCheckError(message: final msg):
    print('Error: $msg');
  case UpdateCheckDisabled():
    print('Updates disabled');
}
```

## API Reference

### AutoUpdater (Static API)

| Member | Type | Description |
|--------|------|-------------|
| `init()` | `Future<void>` | Initialize with ReleaseHub backend |
| `initWithConfig()` | `Future<void>` | Initialize with custom configuration |
| `checkForUpdates()` | `Future<void>` | Manual check with UI feedback |
| `checkForUpdatesSilent()` | `Future<void>` | Silent check (UI only if update available) |
| `dispose()` | `void` | Clean up resources |
| `getDebugInfo()` | `String` | Get debug information |
| `showDebugDialog()` | `Future<void>` | Show debug dialog |
| `navigatorKey` | `GlobalKey<NavigatorState>` | Navigator key for dialogs |
| `scaffoldMessengerKey` | `GlobalKey<ScaffoldMessengerState>` | Scaffold key for snackbars |
| `isInitialized` | `bool` | Whether the updater is initialized |
| `instance` | `AutoUpdaterStandalone?` | Underlying service instance |

## Configuration

### AutoUpdaterConfig

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `baseUrl` | `String` | **required** | ReleaseHub URL (hosted or self-hosted) |
| `appId` | `String` | **required** | Project slug in ReleaseHub |
| `versionPath` | `String` | `'api/check'` | API path (auto-set in ReleaseHub mode) |
| `environment` | `String` | `'stable'` | Release channel name |
| `releaseHubMode` | `bool` | `true` | Enable ReleaseHub API format |
| `checkOnStartup` | `bool` | `true` | Auto-check on initialization |
| `startupDelay` | `Duration` | `2 seconds` | Delay before startup check |
| `skipPermissionCheck` | `bool` | `false` | Skip Android permission dialogs |
| `isDisabled` | `bool` | `false` | Completely disable updates |
| `apkFilenamePattern` | `String` | `'{appId}_update_{version}.apk'` | Downloaded APK filename |
| `includeArchitecture` | `bool` | `true` | Send device arch to server |
| `httpHeaders` | `Map<String, String>?` | `null` | Custom HTTP headers (for API auth) |
| `connectionTimeout` | `Duration` | `30 seconds` | HTTP request timeout |
| `responseFields` | `VersionResponseFields` | default | Custom JSON field mapping for non-ReleaseHub backends |
| `logger` | `Function(String)?` | `null` | Custom logging callback for debugging |

### ReleaseHub API

The plugin uses ReleaseHub's API format:

**Request:**
```
GET {baseUrl}/api/check/{projectSlug}?version=1.0.0&build=10&channel=stable&arch=arm64-v8a
```

**Response:**
```json
{
  "hasUpdate": true,
  "latestVersion": {
    "version": "1.2.0",
    "build": 42,
    "versionString": "1.2.0+42",
    "releaseNotes": "Bug fixes and improvements",
    "minVersion": "1.0.0",
    "isRequired": false
  },
  "download": {
    "url": "/api/download/my-app/42/arm64-v8a"
  }
}
```

### Using Custom Backend (Non-ReleaseHub)

If you have your own backend, disable ReleaseHub mode:

```dart
AutoUpdaterConfig(
  baseUrl: 'https://your-server.com',
  appId: 'com.example.app',
  versionPath: 'version',
  environment: 'prod',
  releaseHubMode: false,  // Use standard mode
  responseFields: VersionResponseFields(
    version: 'app_version',
    build: 'build_number',
    apkUrl: 'download_url',
  ),
)
```

**Custom Backend Response Format:**
```json
{
  "app_version": "1.2.0",
  "build_number": 42,
  "download_url": "https://your-server.com/app-1.2.0.apk"
}
```

## Customizing UI

### Custom Strings (Localization)

```dart
AutoUpdater.init(
  // ...
  strings: AutoUpdaterStrings(
    updateAvailable: 'Aktualizácia dostupná',
    download: 'Stiahnuť',
    later: 'Neskôr',
    noUpdateAvailable: 'Máte najnovšiu verziu',
  ),
);
```

### Custom UI Callbacks (Standalone)

```dart
AutoUpdaterStandalone(
  config: myConfig,
  ui: AutoUpdaterStandaloneUI(
    onShowUpdateAvailable: (context, info, onDownload) {
      showDialog(
        context: context!,
        builder: (ctx) => MyCustomUpdateDialog(
          version: info.displayVersion,
          onDownload: () {
            Navigator.pop(ctx);
            onDownload();
          },
        ),
      );
    },
    onShowError: (context, title, message) {
      MyToast.showError('$title: $message');
    },
  ),
);
```

### Custom UI Callbacks (GetX)

```dart
AutoUpdaterGetxService(
  config: myConfig,
  uiCallbacks: AutoUpdaterUICallbacks(
    onShowUpdateAvailable: (info, onDownload) {
      Get.snackbar('New Version!', 'v${info.displayVersion} is ready');
    },
    buildDownloadProgressDialog: (progress, status, isDownloading) {
      return MyCustomProgressDialog(progress: progress);
    },
  ),
);
```

## Pre-built Widgets

```dart
import 'package:releasehub_updater/autoupdater.dart';

// Version check button (for settings screen)
VersionCheckButton(
  isChecking: updater.isCheckingForUpdate.value,
  onCheck: () => updater.checkForUpdate(silent: false),
  currentVersion: updater.currentVersion?.version,
  buildNumber: updater.currentVersion?.build.toString(),
)

// Update banner
UpdateAvailableBanner(
  versionInfo: updateInfo,
  onUpdate: () => updater.downloadAndInstall(updateInfo),
  onDismiss: () => setState(() => showBanner = false),
)
```

## Architecture Detection

The plugin automatically detects the Android device's CPU architecture and:
- Sends it as a query parameter (`?arch=arm64-v8a`) to ReleaseHub
- Normalizes build numbers for Flutter split APK builds (`--split-per-abi`)

Supported Android architectures:
- `arm64-v8a` (most modern devices)
- `armeabi-v7a` (older 32-bit ARM)
- `x86_64` (emulators, some Chromebooks)
- `x86` (older emulators)

## Debug Mode

For troubleshooting update detection issues:

```dart
// Get debug info
print(AutoUpdater.getDebugInfo());

// Show debug dialog
AutoUpdater.showDebugDialog();
```

Output includes:
- Current app version and build number
- Device architecture
- ReleaseHub URL being used
- Raw vs normalized build numbers

## Disabling in Development

To prevent update checks during development:

```dart
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only enable auto-updater in release builds
  if (!kDebugMode) {
    await AutoUpdater.init(
      baseUrl: 'https://releasehub.dev',
      projectSlug: 'my-app',
    );
  }

  runApp(MyApp());
}
```

## Related Tools

- **[ReleaseHub](https://releasehub.dev)** - Release management platform (required backend)
- **[FLaunch](https://releasehub.dev/flaunch)** - CLI tool for automated builds and uploads

## License

MIT License - see the [LICENSE](LICENSE) file for details.

---

Developed by [Version Two s.r.o.](https://www.versiontwo.sk/)
