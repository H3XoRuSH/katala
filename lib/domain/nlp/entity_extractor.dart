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
    RegExp(r'^(sabihin\s+mo\s+sa\s+akin(\s+na)?)\s+', caseSensitive: false),
    RegExp(r'^(paremind(\s+mo)?(\s+naman)?)\s+', caseSensitive: false),
    RegExp(r'^(paalala(\s+mo)?(\s+na)?)\s+', caseSensitive: false),
    RegExp(r'^(mag-?remind(\s+na)?)\s+', caseSensitive: false),
    RegExp(r'^(remind\s+me(\s+later\s+i\s+mean|\s+later|\s+today)?(\s+to|\s+for)?)\s*[:,\-]?\s*', caseSensitive: false),
    RegExp(r'^(set\s+a\s+reminder(\s+to|\s+for)?)\s*[:,\-]?\s*', caseSensitive: false),
    RegExp(r'^(add\s+reminder(\s+to|\s+for)?)\s*[:,\-]?\s*', caseSensitive: false),
    RegExp(r'^(reminder\s+to)\s+', caseSensitive: false),
    RegExp(r"^(don't\s+forget\s+to)\s+", caseSensitive: false),
    RegExp(r'^(remember\s+to)\s+', caseSensitive: false),
    RegExp(r'^(i\s+need\s+to)\s+', caseSensitive: false),
  ];

  static final List<RegExp> _pureIntentTokens = [
    RegExp(r'^(remind\s+me|set\s+a\s+reminder|add\s+reminder|reminder|pa-?remind|paremind|paalala|mag-?remind|please)$',
        caseSensitive: false),
  ];

  // Temporal phrase regexes matching English & Filipino expressions
  static final List<RegExp> _temporalPatterns = [
    // Combined relative with time: "tomorrow at 3:30 pm", "bukas ng 9 am", "tonight at 8"
    RegExp(
      r'\b(today|tomorrow|tonight|bukas|ngayon|ngayong araw)\s+(at|ng|nang)?\s*(\d{1,2}(:\d{2})?\s*(am|pm)?|noon|midnight)\b',
      caseSensitive: false,
    ),
    // Relative with time-of-day: "tomorrow morning", "this Saturday morning", "later tonight"
    RegExp(
      r'\b(today|tomorrow|tonight|later)\s+(morning|afternoon|evening|night|tonight)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(this|next)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+(morning|afternoon|evening|night)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(this morning|this afternoon|this evening|tonight|bukas ng umaga|bukas ng hapon|bukas ng gabi|ngayong umaga|ngayong hapon|ngayong gabi|mamayang hapon|mamayang gabi|mamayang umaga)\b',
      caseSensitive: false,
    ),
    // Filipino named clock hours: "alas-otso bukas ng umaga", "ng alas-dose ng tanghali", "mamayang alas-singko"
    RegExp(
      r'\b(mamayang\s+)?alas-[a-z]+(\s+bukas)?(\s+ng\s+(umaga|hapon|gabi|tanghali))?\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\bng\s+alas-[a-z]+(\s+ng\s+(umaga|hapon|gabi|tanghali))?\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\bng\s+\d{1,2}(:\d{2})?\s+ng\s+(umaga|hapon|gabi|tanghali)\b',
      caseSensitive: false,
    ),
    // Day of month: "on the 15th", "sa ika-5 ng buwan"
    RegExp(r'\bon\s+the\s+\d+(?:st|nd|rd|th)?\b', caseSensitive: false),
    RegExp(r'\bsa\s+ika-\d+\s+ng\s+buwan\b', caseSensitive: false),
    // Relative durations: "in 15 minutes", "in five minutes", "in a minute"
    RegExp(
      r'\bin\s+(?:a|an|one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?)\b',
      caseSensitive: false,
    ),
    // Repetition: "every 2 hours"
    RegExp(r'\bevery\s+\d+\s+(minutes?|mins?|hours?|hrs?|days?)\b', caseSensitive: false),
    // Contextual triggers: "after lunch", "before the standup", "pagkatapos ng trabaho"
    RegExp(r'\b(after\s+lunch|before\s+the\s+standup|pagkatapos\s+ng\s+trabaho|bago\s+mag-trabaho)\b',
        caseSensitive: false),
    // Clock with word phrases: "at 3 in the afternoon", "by 5pm"
    RegExp(r'\bat\s+\d{1,2}(:\d{2})?\s+in\s+the\s+(morning|afternoon|evening)\b', caseSensitive: false),
    RegExp(r'\bby\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false),
    // "mamayang 5pm", "mamaya", "later"
    RegExp(r'\bmamayang\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false),
    RegExp(r'\b(mamaya|later|soon)\b', caseSensitive: false),
    // Day of week + time: "on Friday at 10 am", "sa Martes ng hapon", "sa Sabado ng hapon", "on Wednesday at 2"
    RegExp(
      r'\b(next|this|sa|ngayong|on)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes|miyerkules|huwebes|biyernes|sabado|linggo)(\s+(at|ng|nang)?\s*(\d{1,2}(:\d{2})?\s*(am|pm)?|noon|midnight|umaga|hapon|gabi|tanghali))?\b',
      caseSensitive: false,
    ),
    // Named times: "at noon", "at midnight", "noon", "midnight"
    RegExp(r'\b(at\s+)?(noon|midnight)\b', caseSensitive: false),
    // Exact clock times
    RegExp(r'\bat\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b', caseSensitive: false),
    RegExp(r'\b\d{1,2}(:\d{2})\s*(am|pm)?\b', caseSensitive: false),
    RegExp(r'\b\d{1,2}\s*(am|pm)\b', caseSensitive: false),
    // Standalone days
    RegExp(r'\b(tomorrow|today|tonight|bukas|ngayon)\b', caseSensitive: false),
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

    // 3. Temporal Expression extraction (longest match wins, remove all matched temporal expressions from working text)
    TemporalExpression? extractedTemporal;
    bool foundTemporal = true;
    while (foundTemporal) {
      foundTemporal = false;
      TemporalExpression? current;
      for (final pattern in _temporalPatterns) {
        final match = pattern.firstMatch(workingText);
        if (match != null) {
          final rawExpr = match.group(0)!.trim();
          if (current == null || rawExpr.length > current.rawText.length) {
            current = TemporalExpression(
              rawText: rawExpr,
              ambiguity: _detectAmbiguity(rawExpr),
            );
          }
        }
      }
      if (current != null) {
        extractedTemporal ??= current;
        workingText = workingText.replaceFirst(current.rawText, ' ').trim();
        foundTemporal = true;
      }
    }

    // 4. Notes extraction (via "note:", "about:", "and ask about", "to reschedule", etc.)
    String? extractedNotes;
    bool isAboutTopic = false;
    final noteMatch = RegExp(
      r'\b(note:|about:|about\s+|tungkol sa\s+|tungkol sa:|na:|and ask about\s+|to reschedule)\s*(.+)?$',
      caseSensitive: false,
    ).firstMatch(workingText);

    if (noteMatch != null) {
      final prefix = noteMatch.group(1)!.toLowerCase();
      isAboutTopic = prefix.startsWith('about') || prefix.startsWith('tungkol');
      if (prefix == 'to reschedule') {
        extractedNotes = 'to reschedule';
      } else {
        extractedNotes = (noteMatch.group(2) ?? '').trim();
      }
      if (extractedNotes.isEmpty) {
        extractedNotes = null;
      }
      workingText = workingText.substring(0, noteMatch.start).trim();
    }

    // Specific dual object notes for communication tasks (e.g., "Email my boss the quarterly report")
    if (extractedNotes == null) {
      final emailObjMatch = RegExp(r'^(email\s+(?:my\s+)?boss)\s+(.+)$', caseSensitive: false).firstMatch(workingText);
      if (emailObjMatch != null) {
        workingText = emailObjMatch.group(1)!;
        extractedNotes = emailObjMatch.group(2)!.trim();
      }
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
      r'\b(call|tawagan|i-tawag|tumawag kay|tumawag sa|text|i-text|itext|i-message|message|email|i-email|send email to|ihatid|sunduin|kausapin|meeting kasama|meet|transfer\s+\d+\s+to)\s+(?:mo\s+)?(?:si\s+|kay\s+|to\s+)?([a-zA-Z\u00C0-\u024F\s\x27]+?)(?=\s+(?:for|note|about|tungkol|sa|at|by|in|tomorrow|today|bukas|mamaya|on)|$)',
      caseSensitive: false,
    ).firstMatch(workingText);

    if (callMatch != null) {
      contactName = callMatch.group(2)?.trim();
    } else {
      final directMatch =
          RegExp(r'^(?:si\s+|kay\s+)([a-zA-Z\u00C0-\u024F\s\x27]+)', caseSensitive: false).firstMatch(workingText);
      if (directMatch != null) {
        contactName = directMatch.group(1)?.trim();
      }
    }

    // 6. Title extraction: remaining cleaned text
    var title = workingText
        .replaceAll(RegExp(r'^[:,\-\s]+'), '')
        .replaceAll(RegExp(r'^(na|to)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(sa|at|ang|the)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (isAboutTopic && extractedNotes != null && extractedNotes.isNotEmpty && title.isEmpty) {
      title = extractedNotes.replaceAll(RegExp(r'^(the|ang)\s+', caseSensitive: false), '').trim();
    } else {
      for (final pure in _pureIntentTokens) {
        if (pure.hasMatch(title)) {
          title = '';
          break;
        }
      }
    }

    if (contactName != null) {
      contactName = _restoreCasing(contactName, input.originalText);
    }

    String? finalTitle;
    if (title.isNotEmpty) {
      final restored = _restoreCasing(title, input.originalText);
      finalTitle = restored[0].toUpperCase() + restored.substring(1);
    }

    return ExtractedEntities(
      title: finalTitle,
      contactName: contactName,
      phoneNumber: extractedPhone,
      url: extractedUrl,
      notes: extractedNotes,
      temporalExpression: extractedTemporal,
      timeExpressionText: extractedTemporal?.rawText,
    );
  }

  String _restoreCasing(String text, String originalText) {
    if (text.isEmpty || originalText.isEmpty) return text;
    final tokens = text.split(' ');
    final restoredTokens = tokens.map((token) {
      if (token.isEmpty) return token;
      // Search for whole word in originalText
      final escaped = RegExp.escape(token);
      final match = RegExp('\\b$escaped\\b', caseSensitive: false).firstMatch(originalText);
      if (match != null) {
        return match.group(0)!;
      }
      // If token contains hyphens like i-text or paki-remind
      final subMatch = RegExp(escaped, caseSensitive: false).firstMatch(originalText);
      if (subMatch != null) {
        return subMatch.group(0)!;
      }
      return token;
    }).toList();
    return restoredTokens.join(' ');
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
