import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/nlp/entity_extractor.dart';
import 'package:katala/domain/nlp/models/raw_transcript.dart';
import 'package:katala/domain/nlp/pre_processor.dart';

void main() {
  group('Katala NLP Generated Testset Runner', () {
    const preProcessor = PreProcessor();
    const extractor = EntityExtractor();

    final file = File('test/domain/nlp/corpus/katala_nlp_testset.json');
    if (!file.existsSync()) {
      test('katala_nlp_testset.json exists', () {
        fail('Testset file not found');
      });
      return;
    }

    final jsonContent = jsonDecode(file.readAsStringSync()) as List<dynamic>;

    for (final rawCase in jsonContent) {
      final testCase = rawCase as Map<String, dynamic>;
      final id = testCase['id'] as String;
      final input = testCase['input'] as String;
      final expected = testCase['expected'] as Map<String, dynamic>;

      test('[$id] "$input"', () {
        final raw = RawTranscript(input);
        final normalized = preProcessor.process(raw);
        final entities = extractor.extract(normalized);

        if (expected['title'] != null) {
          expect(
            entities.title?.toLowerCase(),
            (expected['title'] as String).toLowerCase(),
            reason: '[$id] Title mismatch for input: "$input"',
          );
        }

        if (expected['contact_name'] != null) {
          expect(
            entities.contactName?.toLowerCase(),
            (expected['contact_name'] as String).toLowerCase(),
            reason: '[$id] Contact name mismatch for input: "$input"',
          );
        }

        if (expected['phone_number'] != null) {
          expect(
            entities.phoneNumber,
            expected['phone_number'],
            reason: '[$id] Phone number mismatch for input: "$input"',
          );
        }

        if (expected['url'] != null) {
          expect(
            entities.url,
            expected['url'],
            reason: '[$id] URL mismatch for input: "$input"',
          );
        }
      });
    }
  });
}
