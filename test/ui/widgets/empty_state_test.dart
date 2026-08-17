import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/ui/widgets/empty_state.dart';
import 'package:katala/ui/widgets/katala_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Empty States (TASK-092)', () {
    testWidgets('EmptyTimelineState renders mascot and helpful guidance', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyTimelineState(),
          ),
        ),
      );

      expect(find.text('No reminders yet'), findsOneWidget);
      expect(
        find.text(
          'Tap the mic to speak or use the text bar below to create your first reminder.',
        ),
        findsOneWidget,
      );
      expect(find.byType(KatalaLogo), findsOneWidget);
    });

    testWidgets('AllCaughtUpState renders friendly celebration state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AllCaughtUpState(),
          ),
        ),
      );

      expect(find.text('All caught up! 🎉'), findsOneWidget);
      expect(
        find.text(
          'You have no pending reminders. Enjoy your free time or add a new task anytime.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });
  });
}
