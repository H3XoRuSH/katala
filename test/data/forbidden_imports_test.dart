import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architectural Constraints: Data Layer Boundary Rules', () {
    test('Data layer must NOT import Platform Bridges or UI layer', () {
      final dataDir = Directory('lib/data');
      expect(dataDir.existsSync(), isTrue);

      final dartFiles = dataDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

      final forbiddenImports = [
        'package:flutter/material.dart',
        'package:flutter/cupertino.dart',
        'package:flutter/widgets.dart',
        'package:flutter_local_notifications/',
        'package:katala/ui/',
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
