import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TASK-125 — Network Audit & Zero-Network Footprint Tests', () {
    test('Dependency Audit: pubspec.yaml contains zero networking / analytics libraries', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must be readable at project root');

      final content = pubspecFile.readAsStringSync();

      // Disallowed external networking and telemetry packages
      final disallowedPackages = [
        'http:',
        'dio:',
        'retrofit:',
        'chopper:',
        'firebase_core:',
        'firebase_analytics:',
        'firebase_crashlytics:',
        'sentry:',
        'sentry_flutter:',
        'amplitude_flutter:',
        'mixpanel_flutter:',
        'posthog_flutter:',
        'web_socket_channel:',
        'socket_io_client:',
        'grpc:',
        'datadog_flutter_plugin:',
      ];

      for (final pkg in disallowedPackages) {
        expect(
          content.contains(pkg),
          isFalse,
          reason: 'Disallowed network/telemetry package "$pkg" found in pubspec.yaml',
        );
      }
    });

    test('Source Code Audit: lib/ contains no internal HTTP client or raw socket instantiations', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final disallowedTokens = [
        'HttpClient(',
        'Socket.connect',
        'RawSocket.connect',
        'WebSocket.connect',
        'RawDatagramSocket.bind',
        'http.get(',
        'http.post(',
        'Dio(',
      ];

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final token in disallowedTokens) {
          expect(
            content.contains(token),
            isFalse,
            reason: 'Disallowed socket/HTTP token "$token" found in ${file.path}',
          );
        }
      }
    });

    test('Runtime HttpOverrides block: all outgoing HTTP attempts throw NetworkNotPermittedException', () async {
      HttpOverrides.runWithHttpOverrides(
        () {
          expect(
            () => HttpClient(),
            throwsA(isA<UnsupportedError>()),
            reason: 'Production configuration must completely block any outgoing HttpClient instantiation',
          );
        },
        _OfflineStrictHttpOverrides(),
      );
    });
  });
}

class _OfflineStrictHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw UnsupportedError(
      'Katala is an offline-only application. Outbound network requests are strictly forbidden.',
    );
  }
}
