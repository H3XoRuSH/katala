import 'package:katala/domain/nlp/clock.dart';

/// Controllable clock implementation for unit testing temporal operations.
class FakeClock implements Clock {
  DateTime _current;
  final String timezone;

  FakeClock(DateTime fixedNow, {this.timezone = 'UTC'}) : _current = fixedNow;

  @override
  DateTime now() => _current;

  @override
  String localTimezone() => timezone;

  /// Advance clock forward by [duration].
  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  /// Explicitly update the clock time.
  void set(DateTime dateTime) {
    _current = dateTime;
  }
}
