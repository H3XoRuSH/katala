import 'models/normalized_transcript.dart';
import 'models/raw_transcript.dart';

/// Stage 1 of the deterministic NLP Pipeline: text normalization and STT error correction.
class PreProcessor {
  const PreProcessor();

  static const Map<String, String> _sttCorrections = {
    'rewind me': 'remind me',
    'remain me': 'remind me',
    'remainder to': 'reminder to',
    'remainder': 'reminder',
    'remain to': 'remind to',
    'to morrow': 'tomorrow',
    'to day': 'today',
    'for pm': '4 pm',
    'for am': '4 am',
    'too pm': '2 pm',
    'too am': '2 am',
    'pah remind': 'paremind',
    'pa remind': 'paremind',
    'na remind': 'magremind',
    'p.m.': 'pm',
    'a.m.': 'am',
    'p. m.': 'pm',
    'a. m.': 'am',
    'pm.': 'pm',
    'am.': 'am',
    'later i mean': '',
  };

  static final List<RegExp> _fillerPrefixes = [
    RegExp(r'^(hey\s+katala|hi\s+katala|katala)[,\s]*', caseSensitive: false),
    RegExp(r'^(um|uh|er|ah)[,\s]+', caseSensitive: false),
    RegExp(r'^(can you please|could you please|would you please|can you|could you|would you|please)[,\s]*',
        caseSensitive: false),
    RegExp(r'^(i want to|i need to|i have to)[,\s]*', caseSensitive: false),
    RegExp(r'^(paki-?remind\s+naman(\s+ako|\s+mo)?(\s+na)?)[,\s]*', caseSensitive: false),
    RegExp(r'^(i-remind(\s+mo)?(\s+ako|\s+naman)?(\s+na)?)[,\s]*', caseSensitive: false),
    RegExp(r'^(sabihin\s+mo\s+sa\s+akin(\s+na)?)[,\s]*', caseSensitive: false),
    RegExp(r'^(paki|pwede bang|paki-)[,\s]+', caseSensitive: false),
  ];

  /// Processes raw transcript into a cleaned, normalized transcript.
  NormalizedTranscript process(RawTranscript input) {
    var text = input.text.trim();
    if (text.isEmpty) {
      return NormalizedTranscript(text: '', originalText: input.text);
    }

    // 1. Normalize quotes (curly to straight)
    text = text.replaceAll('‘', "'").replaceAll('’', "'").replaceAll('“', '"').replaceAll('”', '"');

    // 2. Lowercase
    text = text.toLowerCase();

    // 3. Strip mid-sentence filler sounds & duplicate words
    text = text.replaceAll(RegExp(r'\b(um|uh|er)\b', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\bto\s+to\b', caseSensitive: false), 'to');
    text = text.replaceAll(RegExp(r'^[:,\-\s]+'), '').trim();

    // 4. Strip all filler prefixes iteratively
    bool changed = true;
    while (changed && text.isNotEmpty) {
      changed = false;
      for (final pattern in _fillerPrefixes) {
        if (pattern.hasMatch(text)) {
          final newText = text.replaceFirst(pattern, '').replaceAll(RegExp(r'^[:,\-\s]+'), '').trim();
          if (newText != text) {
            text = newText;
            changed = true;
          }
        }
      }
    }

    // 5. Apply STT corrections
    for (final entry in _sttCorrections.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    // 6. Clean punctuation around numbers and ends of sentences
    text = text.replaceAllMapped(RegExp(r'(\d+)\s*:\s*(\d+)'), (m) => '${m[1]}:${m[2]}');
    text = text.replaceAll(RegExp(r'[.!?,;]+$'), '');

    // 7. Collapse multiple whitespace and trim
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return NormalizedTranscript(
      text: text,
      originalText: input.text,
    );
  }
}
