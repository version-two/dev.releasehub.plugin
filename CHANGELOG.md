# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-31

### Added

- Initial release
- Automatic update checking on app startup (configurable)
- Manual update checking via API
- APK download with real-time progress tracking
- Automatic installation triggering via system installer
- Android permission handling (install packages, storage)
- Architecture-aware APK selection (arm64-v8a, armeabi-v7a, x86_64, x86)
- Build number normalization for Flutter split APK builds
- Framework-agnostic core service (`AutoUpdaterCore`)
- Standalone adapter using `ValueNotifier` (no dependencies)
- GetX adapter with reactive state management
- Simple static API (`AutoUpdater`) for quick integration
- Built-in Material Design UI dialogs
- Customizable UI callbacks for all dialogs and notifications
- Localization support via `AutoUpdaterStrings`
- ReleaseHub backend integration
- Custom backend support with configurable field mapping
- Pre-built widgets: `VersionCheckButton`, `UpdateAvailableBanner`, `DownloadProgressWidget`
- Comprehensive debug info generation for troubleshooting
