/// Injectable Clock interface for deterministic time resolution.
abstract class Clock {
  DateTime now();
  String localTimezone();
}

/// Real-world system clock.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  String localTimezone() => DateTime.now().timeZoneName;
}
