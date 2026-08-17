import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import 'package:katala/ui/widgets/text_input_field.dart';
import '../../test_helpers/fake_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testClock = FakeClock(DateTime.utc(2026, 8, 16, 12, 0));

  group('TextInputField Widget (TASK-088)', () {
    testWidgets('Displays debounced live preview and submits input', (tester) async {
      String? submittedText;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(testClock),
            nlpPipelineProvider.overrideWithValue(const NlpPipeline()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TextInputField(
                onSubmit: (text) {
                  submittedText = text;
                },
              ),
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Enter text
      await tester.enterText(textFieldFinder, 'Call Adam tomorrow at 3pm');

      // Advance debounce timer (300ms) and finish animations
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Check preview
      expect(find.text('adam'), findsOneWidget);
      expect(find.textContaining('Aug 17'), findsOneWidget);

      // Submit via submit icon
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(submittedText, 'Call Adam tomorrow at 3pm');
      expect(find.text('Call Adam tomorrow at 3pm'), findsNothing); // Cleared
    });
  });
}
