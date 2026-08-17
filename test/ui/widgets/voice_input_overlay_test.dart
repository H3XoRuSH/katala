import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/ui/widgets/voice_input_overlay.dart';
import '../../test_helpers/fake_speech_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceInputOverlay Widget (TASK-083)', () {
    testWidgets('Emits live transcript from SpeechBridge stream and returns on stop', (tester) async {
      final speechBridge = FakeSpeechBridge(
        transcriptsToEmit: ['Remind me', 'Remind me to call Mom'],
      );

      String? recordedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            speechBridgeProvider.overrideWithValue(speechBridge),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VoiceInputOverlay(
                onResult: (result) {
                  recordedResult = result;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Listening...'), findsOneWidget);
      expect(find.text('Remind me to call Mom'), findsOneWidget);

      // Tap stop/mic button
      await tester.tap(find.byKey(const Key('stop_listening_button')));
      await tester.pump();

      expect(recordedResult, 'Remind me to call Mom');
    });

    testWidgets('Cancel button cancels speech session without invoking onResult', (tester) async {
      final speechBridge = FakeSpeechBridge(
        transcriptsToEmit: ['Draft speech'],
      );

      String? recordedResult;
      bool cancelled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            speechBridgeProvider.overrideWithValue(speechBridge),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VoiceInputOverlay(
                onResult: (result) => recordedResult = result,
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Draft speech'), findsWidgets);

      // Tap cancel close button
      await tester.tap(find.byKey(const Key('cancel_voice_button')));
      await tester.pump();

      expect(recordedResult, isNull);
      expect(cancelled, isTrue);
    });
  });
}
