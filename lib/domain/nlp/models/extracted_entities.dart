import 'temporal_expression.dart';

/// Entities extracted from transcript by Entity Extractor (Stage 3).
class ExtractedEntities {
  final String? title;
  final String? contactName;
  final String? url;
  final String? phoneNumber;
  final String? notes;
  final TemporalExpression? temporalExpression;
  final String? timeExpressionText;

  const ExtractedEntities({
    this.title,
    this.contactName,
    this.url,
    this.phoneNumber,
    this.notes,
    this.temporalExpression,
    this.timeExpressionText,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedEntities &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          contactName == other.contactName &&
          url == other.url &&
          phoneNumber == other.phoneNumber &&
          notes == other.notes &&
          temporalExpression == other.temporalExpression &&
          timeExpressionText == other.timeExpressionText;

  @override
  int get hashCode =>
      title.hashCode ^
      contactName.hashCode ^
      url.hashCode ^
      phoneNumber.hashCode ^
      notes.hashCode ^
      temporalExpression.hashCode ^
      timeExpressionText.hashCode;

  @override
  String toString() =>
      'ExtractedEntities(title: "$title", contact: "$contactName", url: "$url", phone: "$phoneNumber", time: "$timeExpressionText")';
}
