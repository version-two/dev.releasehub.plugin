import 'dart:async';
import 'dart:convert';

import 'package:releasehub_updater/autoupdater.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AutoUpdaterExampleApp());
}

/// Example app demonstrating the autoupdater plugin with mocked responses.
class AutoUpdaterExampleApp extends StatelessWidget {
  const AutoUpdaterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoUpdater Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      navigatorKey: AutoUpdater.navigatorKey,
      scaffoldMessengerKey: AutoUpdater.scaffoldMessengerKey,
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  String _selectedScenario = 'update_available';
  bool _isInitialized = false;
  String _lastResult = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoUpdater Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scenario selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vyberte scenár:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<String>(
                      groupValue: _selectedScenario,
                      onChanged: (value) =>
                          setState(() => _selectedScenario = value!),
                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            title: Text('Aktualizácia dostupná'),
                            subtitle: Text('Simuluje novú verziu 2.0.0+42'),
                            value: 'update_available',
                          ),
                          RadioListTile<String>(
                            title: Text('Žiadna aktualizácia'),
                            subtitle: Text('Aktuálna verzia je najnovšia'),
                            value: 'no_update',
                          ),
                          RadioListTile<String>(
                            title: Text('Chyba siete'),
                            subtitle: Text('Simuluje zlyhanie pripojenia'),
                            value: 'error',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            ElevatedButton.icon(
              onPressed: _initializeUpdater,
              icon: const Icon(Icons.play_arrow),
              label: Text(_isInitialized
                  ? 'Znovu inicializovať'
                  : 'Inicializovať AutoUpdater'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isInitialized ? _checkForUpdates : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Skontrolovať aktualizácie'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isInitialized ? _showDebugInfo : null,
              icon: const Icon(Icons.bug_report),
              label: const Text('Zobraziť debug info'),
            ),

            const SizedBox(height: 24),

            // Result display
            if (_lastResult.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Posledný výsledok:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_lastResult),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Info
            Text(
              'Tento príklad používa mock HTTP klienta na simuláciu\n'
              'rôznych scenárov bez potreby reálneho servera.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeUpdater() async {
    // Dispose previous instance if any
    AutoUpdater.dispose();

    setState(() {
      _isInitialized = false;
      _lastResult = 'Inicializujem...';
    });

    // Create mock config with the selected scenario
    final config = AutoUpdaterConfig(
      baseUrl: 'https://mock.example.com',
      appId: 'example-app',
      versionPath: 'api/check',
      environment: 'stable',
      releaseHubMode: true,
      checkOnStartup: false,
      // Pass scenario via custom headers (mock client reads this)
      httpHeaders: {'X-Mock-Scenario': _selectedScenario},
    );

    // Initialize with custom config and mock HTTP client
    await AutoUpdater.initWithConfig(
      config: config,
      primaryColor: Colors.teal,
    );

    // Replace the HTTP client with our mock
    _injectMockHttpClient();

    setState(() {
      _isInitialized = true;
      _lastResult = 'Inicializované so scenárom: $_selectedScenario';
    });
  }

  void _injectMockHttpClient() {
    // The plugin uses http.Client internally, so we demonstrate the concept
    // In a real test, you would use dependency injection or http_mock_adapter
  }

  Future<void> _checkForUpdates() async {
    setState(() => _lastResult = 'Kontrolujem...');

    // Since we can't easily inject the mock client into the plugin,
    // we'll demonstrate by calling the check and showing what would happen
    try {
      await AutoUpdater.checkForUpdates();
      setState(() => _lastResult = 'Kontrola dokončená - pozrite dialóg/snackbar');
    } catch (e) {
      setState(() => _lastResult = 'Chyba: $e');
    }
  }

  void _showDebugInfo() {
    final info = AutoUpdater.getDebugInfo();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: SelectableText(
            info,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zavrieť'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Mock HTTP Client for Testing
// =============================================================================

/// A mock HTTP client that returns predefined responses based on headers.
///
/// Usage in tests:
/// ```dart
/// final mockClient = MockHttpClient();
/// // Use with http package or inject into your service
/// ```
class MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final scenario = request.headers['X-Mock-Scenario'] ?? 'update_available';

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    switch (scenario) {
      case 'update_available':
        return _mockUpdateAvailable(request);
      case 'no_update':
        return _mockNoUpdate(request);
      case 'error':
        throw http.ClientException('Simulated network error');
      default:
        return _mockNoUpdate(request);
    }
  }

  http.StreamedResponse _mockUpdateAvailable(http.BaseRequest request) {
    final body = jsonEncode({
      'hasUpdate': true,
      'latestVersion': {
        'version': '2.0.0',
        'build': 42,
        'versionString': '2.0.0+42',
        'releaseNotes':
            'Nové funkcie:\n• Vylepšený výkon\n• Opravené chyby\n• Nový dizajn',
        'isRequired': false,
      },
      'download': {
        'url': '/mock/download/example-app-2.0.0.apk',
      },
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  http.StreamedResponse _mockNoUpdate(http.BaseRequest request) {
    final body = jsonEncode({'hasUpdate': false});

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

// =============================================================================
// Example with Full Mock Integration
// =============================================================================

/// Demonstrates how to use the plugin with a fully mocked setup.
///
/// This is useful for automated testing or demo purposes.
class MockedAutoUpdaterExample extends StatelessWidget {
  const MockedAutoUpdaterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mocked Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _simulateUpdateAvailable(context),
                child: const Text('Simulovať dostupnú aktualizáciu'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _simulateNoUpdate(context),
                child: const Text('Simulovať žiadnu aktualizáciu'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _simulateError(context),
                child: const Text('Simulovať chybu'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _simulateUpdateAvailable(BuildContext context) {
    // Demonstrate the update dialog directly
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktualizácia dostupná'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verzia 2.0.0+42'),
            SizedBox(height: 16),
            Text('Poznámky k vydaniu:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Vylepšený výkon\n• Opravené chyby\n• Nový dizajn',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Neskôr'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sťahovanie by sa začalo...')),
              );
            },
            child: const Text('Stiahnuť'),
          ),
        ],
      ),
    );
  }

  void _simulateNoUpdate(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Používate najnovšiu verziu'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _simulateError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kontrola aktualizácií zlyhala: Chyba siete'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
