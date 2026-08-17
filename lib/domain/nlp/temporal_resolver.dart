import 'clock.dart';
import 'models/temporal_expression.dart';

/// Stage 4 of the deterministic NLP Pipeline: temporal expression resolution with Clock injection.
class TemporalResolver {
  const TemporalResolver();

  static const Map<String, int> _dayOfWeekMap = {
    'monday': DateTime.monday,
    'lunes': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'martes': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'miyerkules': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'huwebes': DateTime.thursday,
    'friday': DateTime.friday,
    'biyernes': DateTime.friday,
    'saturday': DateTime.saturday,
    'sabado': DateTime.saturday,
    'sunday': DateTime.sunday,
    'linggo': DateTime.sunday,
  };

  DateTime _dt(DateTime base, int year, int month, int day, int hour, [int minute = 0]) {
    return base.isUtc ? DateTime.utc(year, month, day, hour, minute) : DateTime(year, month, day, hour, minute);
  }

  /// Resolves [expression] into a concrete [DateTime] using [clock].
  TemporalResult resolve(TemporalExpression? expression, {required Clock clock}) {
    final tz = clock.localTimezone();
    if (expression == null || expression.rawText.trim().isEmpty) {
      return TemporalResult(timezone: tz);
    }

    if (expression.ambiguity == TemporalAmbiguity.bareNumber) {
      return TemporalResult(
        timezone: tz,
        ambiguity: TemporalAmbiguity.bareNumber,
      );
    }

    final raw = expression.rawText.trim().toLowerCase();
    final now = clock.now();

    // 1. Relative durations: "in 15 minutes", "in a minute", "in an hour", "in 3 days"
    final relativeMatch = RegExp(r'^in\s+(\d+|a|an|one)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?)$').firstMatch(raw);
    if (relativeMatch != null) {
      final amountStr = relativeMatch.group(1)!;
      final amount = (amountStr == 'a' || amountStr == 'an' || amountStr == 'one') ? 1 : int.parse(amountStr);
      final unit = relativeMatch.group(2)!;

      if (unit.startsWith('min') || unit.startsWith('m')) {
        return TemporalResult(resolvedTime: now.add(Duration(minutes: amount)), timezone: tz);
      } else if (unit.startsWith('h')) {
        return TemporalResult(resolvedTime: now.add(Duration(hours: amount)), timezone: tz);
      } else if (unit.startsWith('d')) {
        return TemporalResult(resolvedTime: now.add(Duration(days: amount)), timezone: tz);
      } else if (unit.startsWith('w')) {
        return TemporalResult(resolvedTime: now.add(Duration(days: amount * 7)), timezone: tz);
      }
    }

    // 2. "later" or "mamaya"
    if (raw == 'later' || raw == 'mamaya' || raw == 'soon') {
      var target = now.add(const Duration(hours: 2));
      if (target.hour >= 22 || target.hour < 7) {
        final tomorrow = now.add(const Duration(days: 1));
        target = _dt(now, tomorrow.year, tomorrow.month, tomorrow.day, 8, 0);
      }
      return TemporalResult(resolvedTime: target, timezone: tz);
    }

    // 3. Named times of day
    if (raw == 'noon' || raw == 'at noon') {
      var target = _dt(now, now.year, now.month, now.day, 12, 0);
      if (target.isBefore(now)) target = target.add(const Duration(days: 1));
      return TemporalResult(resolvedTime: target, timezone: tz);
    }
    if (raw == 'midnight' || raw == 'at midnight') {
      final tomorrow = now.add(const Duration(days: 1));
      return TemporalResult(resolvedTime: _dt(now, tomorrow.year, tomorrow.month, tomorrow.day, 0, 0), timezone: tz);
    }

    // 4. Combined relative + time: "tomorrow at 3pm", "bukas ng 9am", "today at 5pm", "tonight at 8pm", "mamayang 5pm"
    final combinedMatch = RegExp(
      r'^(today|tomorrow|tonight|bukas|ngayon|ngayong araw|mamayang|mamaya)\s+(?:at|ng|nang)?\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm)?|noon|midnight)$',
    ).firstMatch(raw);

    if (combinedMatch != null) {
      final dayStr = combinedMatch.group(1)!;
      final timeStr = combinedMatch.group(2)!;

      final isTomorrow = dayStr == 'tomorrow' || dayStr == 'bukas';
      final isTonight = dayStr == 'tonight';
      final baseDate = isTomorrow ? now.add(const Duration(days: 1)) : now;

      final (hour, minute) = _parseClockTime(timeStr, isTonight: isTonight);
      var target = _dt(now, baseDate.year, baseDate.month, baseDate.day, hour, minute);
      if (!isTomorrow && !isTonight && target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      return TemporalResult(
        resolvedTime: target,
        timezone: tz,
      );
    }

    // 5. Named day-parts: "this morning", "tonight", "bukas ng gabi", "ngayong hapon", "mamayang hapon"
    final dayPartMatch = RegExp(
      r'^(this morning|this afternoon|this evening|tonight|bukas ng umaga|bukas ng hapon|bukas ng gabi|ngayong umaga|ngayong hapon|ngayong gabi|mamayang hapon|mamayang gabi|mamayang umaga)$',
    ).firstMatch(raw);

    if (dayPartMatch != null) {
      final phrase = dayPartMatch.group(1)!;
      final isTomorrow = phrase.startsWith('bukas');
      final baseDate = isTomorrow ? now.add(const Duration(days: 1)) : now;

      int hour = 9;
      if (phrase.contains('afternoon') || phrase.contains('hapon')) {
        hour = 14;
      } else if (phrase.contains('evening') || phrase.contains('gabi') || phrase.contains('tonight')) {
        hour = 20;
      }

      var target = _dt(now, baseDate.year, baseDate.month, baseDate.day, hour, 0);
      if (!isTomorrow && target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      return TemporalResult(resolvedTime: target, timezone: tz);
    }

    // 6. Day of week + time: "on Friday at 5pm", "sa Lunes ng 9am"
    final dowMatch = RegExp(
      r'^(?:next|this|sa|ngayong|on)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes|miyerkules|huwebes|biyernes|sabado|linggo)\s*(?:at|ng|nang)?\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)?$',
    ).firstMatch(raw);

    if (dowMatch != null) {
      final dowName = dowMatch.group(1)!;
      final timeStr = dowMatch.group(2);
      final targetDow = _dayOfWeekMap[dowName]!;

      int daysUntil = (targetDow - now.weekday) % 7;
      if (daysUntil <= 0) daysUntil += 7; // strictly upcoming

      final targetDate = now.add(Duration(days: daysUntil));
      final (hour, minute) = timeStr != null ? _parseClockTime(timeStr) : (9, 0);

      return TemporalResult(
        resolvedTime: _dt(now, targetDate.year, targetDate.month, targetDate.day, hour, minute),
        timezone: tz,
      );
    }

    // 7. Exact clock time: "at 3:30 pm", "at 14:00", "3pm"
    final exactMatch = RegExp(r'^(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(raw);
    if (exactMatch != null) {
      final (hour, minute) = _parseClockTime(raw.replaceFirst('at ', ''));
      var target = _dt(now, now.year, now.month, now.day, hour, minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      return TemporalResult(resolvedTime: target, timezone: tz);
    }

    // 8. Standalone days: "tomorrow", "bukas", "today", "ngayon"
    if (raw == 'tomorrow' || raw == 'bukas') {
      final tomorrow = now.add(const Duration(days: 1));
      return TemporalResult(resolvedTime: _dt(now, tomorrow.year, tomorrow.month, tomorrow.day, 9, 0), timezone: tz);
    }
    if (raw == 'today' || raw == 'ngayon') {
      var target = _dt(now, now.year, now.month, now.day, 9, 0);
      if (target.isBefore(now)) target = now.add(const Duration(hours: 1));
      return TemporalResult(resolvedTime: target, timezone: tz);
    }

    return TemporalResult(timezone: tz);
  }

  (int, int) _parseClockTime(String text, {bool isTonight = false}) {
    final clean = text.trim().toLowerCase();
    if (clean == 'noon') return (12, 0);
    if (clean == 'midnight') return (0, 0);

    final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(clean);
    if (match == null) return (9, 0);

    int hour = int.parse(match.group(1)!);
    final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
    final period = match.group(3);

    if (period == 'pm') {
      if (hour < 12) hour += 12;
    } else if (period == 'am') {
      if (hour == 12) hour = 0;
    } else if (isTonight && hour < 12) {
      hour += 12;
    }

    return (hour, minute);
  }
}
