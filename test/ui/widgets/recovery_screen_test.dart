import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/ui/widgets/recovery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecoveryScreen (TASK-092)', () {
    testWidgets('renders corruption warning and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecoveryScreen(),
        ),
      );

      expect(find.text('Database Recovery'), findsOneWidget);
      expect(find.text('Database integrity check failed'), findsOneWidget);
      expect(find.text('Restore from Backup'), findsOneWidget);
      expect(find.text('Reset Database'), findsOneWidget);
    });

    testWidgets('tapping Restore from Backup triggers onRestoreBackup callback', (tester) async {
      bool restored = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryScreen(
            onRestoreBackup: () async {
              restored = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Restore from Backup'));
      await tester.pumpAndSettle();

      expect(restored, isTrue);
      expect(find.text('Restoration completed successfully.'), findsOneWidget);
    });

    testWidgets('tapping Reset Database shows confirmation and triggers onResetDatabase', (tester) async {
      bool reset = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryScreen(
            onResetDatabase: () async {
              reset = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Reset Database'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Database?'), findsOneWidget);

      // Confirm reset
      await tester.tap(find.text('Reset').last);
      await tester.pumpAndSettle();

      expect(reset, isTrue);
      expect(find.text('Database reset successfully.'), findsOneWidget);
    });
  });
}
