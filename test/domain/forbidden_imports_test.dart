import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architectural Constraints: Layer Dependency Rules', () {
    test('Domain layer must have ZERO imports from Flutter UI, Drift, or Platform Bridges', () {
      final domainDir = Directory('lib/domain');
      expect(domainDir.existsSync(), isTrue);

      final dartFiles = domainDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      final forbiddenImports = [
        'package:flutter/material.dart',
        'package:flutter/cupertino.dart',
        'package:flutter/widgets.dart',
        'package:drift/',
        'package:flutter_riverpod/',
        'package:flutter_local_notifications/',
        'package:permission_handler/',
        'package:url_launcher/',
        'package:katala/ui/',
        'package:katala/data/',
        'package:katala/platform/bridges/',
      ];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final forbidden in forbiddenImports) {
          expect(
            content.contains(forbidden),
            isFalse,
            reason: '${file.path} contains forbidden import "$forbidden"',
          );
        }
      }
    });
  });
}
