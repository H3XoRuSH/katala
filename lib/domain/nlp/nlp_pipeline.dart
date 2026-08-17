import '../entities/parsed_reminder.dart';
import '../enums/intent_type.dart';
import '../enums/validation_issue.dart';
import 'clock.dart';
import 'entity_extractor.dart';
import 'intent_detector.dart';
import 'models/raw_transcript.dart';
import 'models/temporal_expression.dart';
import 'pre_processor.dart';
import 'temporal_resolver.dart';
import 'validator.dart';

/// The deterministic 5-stage NLP pipeline orchestrator.
///
/// Converts a speech transcript string into a [ParsedReminder] with explicit validation issues.
/// All stages are pure and deterministic (given identical transcript + Clock).
class NlpPipeline {
  final PreProcessor preProcessor;
  final IntentDetector intentDetector;
  final EntityExtractor entityExtractor;
  final TemporalResolver temporalResolver;
  final Validator validator;

  const NlpPipeline({
    this.preProcessor = const PreProcessor(),
    this.intentDetector = const IntentDetector(),
    this.entityExtractor = const EntityExtractor(),
    this.temporalResolver = const TemporalResolver(),
    this.validator = const Validator(),
  });

  /// Parses [transcript] through the 5-stage NLP pipeline using [clock].
  ParsedReminder parse(String transcript, {required Clock clock}) {
    // ---------------------------------------------------------
    // Stage 1: Pre-Processor (normalize, strip fillers, STT corrections)
    // ---------------------------------------------------------
    final raw = RawTranscript(transcript);
    final normalized = preProcessor.process(raw);

    // ---------------------------------------------------------
    // Stage 2: Intent Detector (classify intent pattern)
    // ---------------------------------------------------------
    final intentClassification = intentDetector.detect(normalized);

    // Infer specific action intent type before extraction
    IntentType inferredIntent = intentClassification.intent;
    final lower = normalized.text;
    if (lower.startsWith('call') ||
        lower.contains(' tawagan') ||
        lower.contains('tawagan') ||
        lower.contains('tumawag') ||
        lower.contains('call ')) {
      inferredIntent = IntentType.call;
    } else if (lower.startsWith('text') ||
        lower.contains(' i-text') ||
        lower.contains('i-text') ||
        lower.contains('itext') ||
        lower.contains('message') ||
        lower.contains('sms')) {
      inferredIntent = IntentType.text;
    } else if (lower.startsWith('email') || lower.contains('i-email') || lower.contains('email ')) {
      inferredIntent = IntentType.email;
    }

    // ---------------------------------------------------------
    // Stage 3: Entity Extractor (URL, phone, temporal, contact, notes, title)
    // ---------------------------------------------------------
    final entities = entityExtractor.extract(normalized, inferredIntent);
    if (entities.url != null) {
      inferredIntent = IntentType.openUrl;
    }

    // ---------------------------------------------------------
    // Stage 4: Temporal Resolver (resolve time expression -> DateTime)
    // ---------------------------------------------------------
    final temporalResult = temporalResolver.resolve(entities.temporalExpression, clock: clock);

    final initialIssues = <ValidationIssue>[];
    if (temporalResult.ambiguity == TemporalAmbiguity.bareNumber) {
      initialIssues.add(ValidationIssue.ambiguousTime);
    }
    if (!intentClassification.isExplicitPatternMatched &&
        (entities.title == null ||
            entities.temporalExpression == null ||
            normalized.text.isEmpty ||
            lower.startsWith('how are you') ||
            lower.startsWith('what is') ||
            lower.startsWith("what's"))) {
      initialIssues.add(ValidationIssue.unrecognizedIntent);
    }

    final candidate = ParsedReminder(
      title: entities.title,
      notes: entities.notes,
      contactName: entities.contactName,
      phoneNumber: entities.phoneNumber,
      url: entities.url,
      scheduledTime: temporalResult.resolvedTime,
      timezone: temporalResult.timezone,
      intentType: inferredIntent,
      originalTranscript: transcript,
      issues: initialIssues,
    );

    // ---------------------------------------------------------
    // Stage 5: Validator (produce final list of ValidationIssue)
    // ---------------------------------------------------------
    final validatedIssues = validator.validate(candidate, clock: clock);

    return candidate.copyWith(issues: validatedIssues);
  }
}
