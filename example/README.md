# AutoUpdater Example

This example demonstrates the `autoupdater` plugin with mocked HTTP responses.

## Features Demonstrated

- **Update Available**: Simulates a server response indicating a new version is available
- **No Update**: Simulates a server response indicating the app is up to date
- **Error**: Simulates a network/server error

## Running the Example

```bash
cd example
fvm flutter pub get
fvm flutter run
```

## How It Works

The example uses a custom HTTP client that intercepts requests and returns mock responses based on query parameters. This allows testing the update flow without a real server.

### Mock Scenarios

1. **Update Available** (`mock_scenario=update_available`)
   - Returns version 2.0.0+42
   - Shows update dialog with release notes

2. **No Update** (`mock_scenario=no_update`)
   - Returns `hasUpdate: false`
   - Shows "You are using the latest version" snackbar

3. **Error** (`mock_scenario=error`)
   - Simulates a network timeout
   - Shows error snackbar

## Localization Example

The example includes Slovak localization to demonstrate the `AutoUpdaterStrings` customization:

```dart
AutoUpdater.init(
  // ...
  strings: AutoUpdaterStrings(
    updateAvailable: 'Aktualizácia dostupná',
    download: 'Stiahnuť',
    later: 'Neskôr',
  ),
);
```
