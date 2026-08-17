import '../enums/intent_type.dart';
import 'models/extracted_entities.dart';
import 'models/normalized_transcript.dart';
import 'models/temporal_expression.dart';

/// Stage 3 of the deterministic NLP Pipeline: entity extraction.
///
/// Order of extraction (CRITICAL per ARCHITECTURE.md §9.3):
/// 1. URL
/// 2. Phone Number
/// 3. Temporal Expressions
/// 4. Notes
/// 5. Action & Contact Name
/// 6. Title
class EntityExtractor {
  const EntityExtractor();

  static final RegExp _urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

  // Phone numbers: +639171234567, 09171234567, +1-234-567-8900, (02) 123-4567, 7+ digits
  static final RegExp _phoneRegex = RegExp(
    r'\b(?:\+?63|0)?9\d{9}\b|\b\+?\d{1,4}[-.\s]?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}\b|\b\d{7,15}\b',
  );

  static final List<RegExp> _intentPrefixes = [
    RegExp(r'^(pa-?remind(\s+mo)?(\s+ko|\s+ako|\s+naman)?(\s+na)?)\s+', caseSensitive: false),
    RegExp(r'^(remind\s+mo\s+(ko|ako|naman)(\s+na)?)\s+', caseSensitive: false),
    RegExp(r'^(ipaalala\s+mo(\s+sa\s+akin)?(\s+na)?)\s+', caseSensitive: false),
    RegExp(r'^(paremind(\s+mo)?(\s+naman)?)\s+', caseSensitive: false),
    RegExp(r'^(paalala(\s+mo)?)\s+', caseSensitive: false),
    RegExp(r'^(mag-?remind(\s+na)?)\s+', caseSensitive: false),
    RegExp(r'^(remind\s+me(\s+to|\s+later\s+to|\s+today\s+to)?)\s+', caseSensitive: false),
    RegExp(r'^(set\s+a\s+reminder(\s+to|\s+for)?)\s+', caseSensitive: false),
    RegExp(r'^(add\s+reminder(\s+to|\s+for)?)\s+', caseSensitive: false),
    RegExp(r'^(reminder\s+to)\s+', caseSensitive: false),
    RegExp(r"^(don't\s+forget\s+to)\s+", caseSensitive: false),
    RegExp(r'^(remember\s+to)\s+', caseSensitive: false),
    RegExp(r'^(i\s+need\s+to)\s+', caseSensitive: false),
  ];

  static final List<RegExp> _pureIntentTokens = [
    RegExp(r'^(remind\s+me|set\s+a\s+reminder|add\s+reminder|reminder|pa-?remind|paremind|paalala|mag-?remind)$',
        caseSensitive: false),
  ];

  // Temporal phrase regexes matching English & Filipino expressions
  static final List<RegExp> _temporalPatterns = [
    // Combined relative/named: "tomorrow at 3:30 pm", "bukas ng 9 am", "tonight at 8"
    RegExp(
      r'\b(today|tomorrow|tonight|bukas|ngayon|ngayong araw)\s+(at|ng|nang)?\s*(\d{1,2}(:\d{2})?\s*(am|pm)?|noon|midnight)\b',
      caseSensitive: false,
    ),
    // Relative with time-of-day: "this morning at 9", "bukas ng umaga", "ngayong hapon", "mamayang gabi"
    RegExp(
      r'\b(this morning|this afternoon|this evening|tonight|bukas ng umaga|bukas ng hapon|bukas ng gabi|ngayong umaga|ngayong hapon|ngayong gabi|mamayang hapon|mamayang gabi|mamayang umaga)\b',
      caseSensitive: false,
    ),
    // Relative duration: "in 15 minutes", "in a minute", "in an hour", "in 3 days"
    RegExp(r'\bin\s+(?:a|an|one|\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?)\b', caseSensitive: false),
    // "mamayang 5pm", "mamayang 5 pm", "mamaya"
    RegExp(r'\bmamayang\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false),
    RegExp(r'\b(mamaya|later|soon)\b', caseSensitive: false),
    // Day of week + time: "on Friday at 5pm", "next monday at 10am", "this friday 5pm", "sa lunes ng 9am"
    RegExp(
      r'\b(next|this|sa|ngayong|on)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes|miyerkules|huwebes|biyernes|sabado|linggo)\s*(at|ng|nang)?\s*(\d{1,2}(:\d{2})?\s*(am|pm)?)?\b',
      caseSensitive: false,
    ),
    // Named times with or without 'at': "at noon", "at midnight", "noon", "midnight"
    RegExp(r'\b(at\s+)?(noon|midnight)\b', caseSensitive: false),
    // Exact clock time: "at 3:30 pm", "at 3pm", "at 3 pm", "at 14:00", "at 3"
    RegExp(r'\bat\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false),
    RegExp(r'\b\d{1,2}(:\d{2})\s*(am|pm)?\b', caseSensitive: false),
    RegExp(r'\b\d{1,2}\s*(am|pm)\b', caseSensitive: false),
    // Standalone days: "tomorrow", "today", "bukas", "ngayon"
    RegExp(r'\b(tomorrow|today|bukas|ngayon)\b', caseSensitive: false),
  ];

  /// Extracts entities from [input] given the detected [intent].
  ExtractedEntities extract(NormalizedTranscript input, [IntentType intent = IntentType.general]) {
    var workingText = input.text.trim();
    if (workingText.isEmpty) {
      return const ExtractedEntities();
    }

    // 1. URL extraction
    String? extractedUrl;
    final urlMatch = _urlRegex.firstMatch(workingText);
    if (urlMatch != null) {
      extractedUrl = urlMatch.group(0);
      workingText = workingText.replaceRange(urlMatch.start, urlMatch.end, ' ').trim();
    }

    // 2. Phone Number extraction
    String? extractedPhone;
    final phoneMatch = _phoneRegex.firstMatch(workingText);
    if (phoneMatch != null) {
      extractedPhone = phoneMatch.group(0);
      workingText = workingText.replaceRange(phoneMatch.start, phoneMatch.end, ' ').trim();
    }

    // 3. Temporal Expression extraction (longest match wins)
    TemporalExpression? extractedTemporal;
    for (final pattern in _temporalPatterns) {
      final match = pattern.firstMatch(workingText);
      if (match != null) {
        final rawExpr = match.group(0)!.trim();
        if (extractedTemporal == null || rawExpr.length > extractedTemporal.rawText.length) {
          extractedTemporal = TemporalExpression(
            rawText: rawExpr,
            ambiguity: _detectAmbiguity(rawExpr),
          );
        }
      }
    }

    if (extractedTemporal != null) {
      workingText = workingText.replaceFirst(extractedTemporal.rawText, ' ').trim();
    }

    // 4. Notes extraction (via "note:", "about:", "tungkol sa", "na:")
    String? extractedNotes;
    bool isAboutTopic = false;
    final noteMatch = RegExp(r'\b(note:|about:|about\s+|tungkol sa\s+|tungkol sa:|na:)\s*(.+)$', caseSensitive: false)
        .firstMatch(workingText);
    if (noteMatch != null) {
      final prefix = noteMatch.group(1)!.toLowerCase();
      isAboutTopic = prefix.startsWith('about') || prefix.startsWith('tungkol');
      extractedNotes = noteMatch.group(2)?.trim();
      workingText = workingText.substring(0, noteMatch.start).trim();
    }

    // Strip leading intent prefixes
    for (final pattern in _intentPrefixes) {
      if (pattern.hasMatch(workingText)) {
        workingText = workingText.replaceFirst(pattern, '').trim();
        break;
      }
    }

    // 5. Contact Name / Action
    String? contactName;
    final callMatch = RegExp(
      r'\b(call|tawagan|i-tawag|tumawag kay|tumawag sa|text|i-text|itext|i-message|message|email|i-email|send email to)\s+(?:mo\s+)?(?:si\s+|kay\s+|to\s+)?([a-zA-Z\u00C0-\u024F\s]+)',
      caseSensitive: false,
    ).firstMatch(workingText);

    if (callMatch != null) {
      contactName = callMatch.group(2)?.trim();
    } else {
      final directMatch =
          RegExp(r'^(?:si\s+|kay\s+)([a-zA-Z\u00C0-\u024F\s]+)', caseSensitive: false).firstMatch(workingText);
      if (directMatch != null) {
        contactName = directMatch.group(1)?.trim();
      }
    }

    // 6. Title extraction: remaining cleaned text
    var title = workingText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (isAboutTopic && extractedNotes != null && extractedNotes.isNotEmpty) {
      title = extractedNotes;
    } else if (contactName != null && contactName.isNotEmpty) {
      title = contactName;
    } else {
      for (final pure in _pureIntentTokens) {
        if (pure.hasMatch(title)) {
          title = '';
          break;
        }
      }
    }

    return ExtractedEntities(
      title: title.isEmpty ? null : title,
      contactName: contactName,
      phoneNumber: extractedPhone,
      url: extractedUrl,
      notes: extractedNotes,
      temporalExpression: extractedTemporal,
      timeExpressionText: extractedTemporal?.rawText,
    );
  }

  TemporalAmbiguity _detectAmbiguity(String text) {
    // Bare number ambiguity: "at 8", "at 3" (missing am/pm)
    final bareMatch = RegExp(r'^at\s+\d{1,2}$', caseSensitive: false).hasMatch(text.trim());
    if (bareMatch) {
      return TemporalAmbiguity.bareNumber;
    }
    return TemporalAmbiguity.none;
  }
}
