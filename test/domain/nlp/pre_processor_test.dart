import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/nlp/models/raw_transcript.dart';
import 'package:katala/domain/nlp/pre_processor.dart';

void main() {
  group('Stage 1: PreProcessor', () {
    const preProcessor = PreProcessor();

    test('lowercases text and collapses whitespace', () {
      const input = RawTranscript('   REMIND    ME   TO BUY MILK   ');
      final result = preProcessor.process(input);
      expect(result.text, 'remind me to buy milk');
    });

    test('normalizes curly quotes to straight quotes', () {
      const input = RawTranscript('‘don’t forget’ “meeting”');
      final result = preProcessor.process(input);
      expect(result.text, '\'don\'t forget\' "meeting"');
    });

    test('strips conversational filler prefixes', () {
      expect(preProcessor.process(const RawTranscript('Um, remind me')).text, 'remind me');
      expect(preProcessor.process(const RawTranscript('uh, call Adam')).text, 'call adam');
      expect(preProcessor.process(const RawTranscript('Please remind me to call mom')).text, 'remind me to call mom');
      expect(preProcessor.process(const RawTranscript('Can you please set a reminder')).text, 'set a reminder');
      expect(preProcessor.process(const RawTranscript('I want to buy bread')).text, 'buy bread');
      expect(preProcessor.process(const RawTranscript('paki remind me')).text, 'remind me');
    });

    test('applies STT corrections table', () {
      expect(preProcessor.process(const RawTranscript('rewind me to eat')).text, 'remind me to eat');
      expect(preProcessor.process(const RawTranscript('remainder to pray')).text, 'reminder to pray');
      expect(preProcessor.process(const RawTranscript('call to morrow')).text, 'call tomorrow');
      expect(preProcessor.process(const RawTranscript('leave for pm')).text, 'leave 4 pm');
      expect(preProcessor.process(const RawTranscript('pah remind bumili')).text, 'paremind bumili');
    });
  });
}
