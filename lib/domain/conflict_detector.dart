import 'entities/reminder.dart';

/// Schedule conflict detector for calculating ±15 minute overlaps and proposing alternative times.
class ConflictDetector {
  const ConflictDetector();

  /// Conflict window in minutes (±15 min).
  static const int conflictWindowMinutes = 15;

  /// Detects all reminders whose scheduled time falls within ±15 minutes of [candidateTime].
  List<Reminder> detectConflicts(
    DateTime candidateTime,
    List<Reminder> pendingReminders,
  ) {
    final candidateUtc = candidateTime.toUtc();
    const conflictWindow = Duration(minutes: conflictWindowMinutes);

    return pendingReminders.where((reminder) {
      final triggerTime = reminder.trigger?.scheduledTimeUtc;
      if (triggerTime == null) return false;
      final diff = triggerTime.toUtc().difference(candidateUtc).abs();
      return diff <= conflictWindow;
    }).toList();
  }

  /// Suggests the nearest alternative time slot (+30 min or -30 min) without conflicts.
  DateTime suggestAlternative(
    DateTime candidateTime,
    List<Reminder> conflictingReminders,
  ) {
    if (conflictingReminders.isEmpty) return candidateTime;

    final conflictTimes = conflictingReminders.map((r) => r.trigger!.scheduledTimeUtc.toUtc()).toList()..sort();

    final latestConflict = conflictTimes.last;
    final forwardSlot = latestConflict.add(const Duration(minutes: 30));

    final earliestConflict = conflictTimes.first;
    final backwardSlot = earliestConflict.subtract(const Duration(minutes: 30));

    final isBackwardConflicted = conflictingReminders.any((r) =>
        r.trigger!.scheduledTimeUtc.toUtc().difference(backwardSlot).abs() <=
        const Duration(minutes: conflictWindowMinutes));

    if (!isBackwardConflicted && backwardSlot.isAfter(DateTime.now().toUtc())) {
      return candidateTime.isUtc ? backwardSlot : backwardSlot.toLocal();
    }

    return candidateTime.isUtc ? forwardSlot : forwardSlot.toLocal();
  }
}
