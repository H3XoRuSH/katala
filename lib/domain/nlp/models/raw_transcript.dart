/// Unprocessed raw speech recognition transcript.
class RawTranscript {
  final String text;
  const RawTranscript(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RawTranscript && runtimeType == other.runtimeType && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'RawTranscript("$text")';
}
