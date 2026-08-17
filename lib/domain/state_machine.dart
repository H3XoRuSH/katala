import 'entities/reminder.dart';
import 'enums/reminder_status.dart';
import 'errors.dart';
import 'result.dart';

/// Maximum allowed snoozes before further snooze attempts are rejected by the state machine.
const int kMaxSnoozeCount = 10;

/// Pure function executing a state transition on a [Reminder] with optimistic version increment and guard checks.
Result<Reminder, InvalidStateTransition> transition(
  Reminder current,
  ReminderStatus target, {
  DateTime? now,
}) {
  final transitionTime = now ?? DateTime.now();

  // Terminal states allow no outgoing transitions.
  if (current.status == ReminderStatus.completed || current.status == ReminderStatus.dismissed) {
    return Failure(InvalidStateTransition(current.status, target));
  }

  return switch ((current.status, target)) {
    // PENDING transitions
    (ReminderStatus.pending, ReminderStatus.completed) => Success(
        current.copyWith(
          status: ReminderStatus.completed,
          version: current.version + 1,
          updatedAt: transitionTime,
          completedAt: transitionTime,
        ),
      ),
    (ReminderStatus.pending, ReminderStatus.snoozed) => current.snoozeCount < kMaxSnoozeCount
        ? Success(
            current.copyWith(
              status: ReminderStatus.snoozed,
              snoozeCount: current.snoozeCount + 1,
              version: current.version + 1,
              updatedAt: transitionTime,
            ),
          )
        : Failure(InvalidStateTransition(current.status, target)),
    (ReminderStatus.pending, ReminderStatus.dismissed) => Success(
        current.copyWith(
          status: ReminderStatus.dismissed,
          version: current.version + 1,
          updatedAt: transitionTime,
        ),
      ),

    // SNOOZED transitions
    (ReminderStatus.snoozed, ReminderStatus.pending) => Success(
        current.copyWith(
          status: ReminderStatus.pending,
          version: current.version + 1,
          updatedAt: transitionTime,
        ),
      ),
    (ReminderStatus.snoozed, ReminderStatus.snoozed) => current.snoozeCount < kMaxSnoozeCount
        ? Success(
            current.copyWith(
              status: ReminderStatus.snoozed,
              snoozeCount: current.snoozeCount + 1,
              version: current.version + 1,
              updatedAt: transitionTime,
            ),
          )
        : Failure(InvalidStateTransition(current.status, target)),
    (ReminderStatus.snoozed, ReminderStatus.completed) => Success(
        current.copyWith(
          status: ReminderStatus.completed,
          version: current.version + 1,
          updatedAt: transitionTime,
          completedAt: transitionTime,
        ),
      ),
    (ReminderStatus.snoozed, ReminderStatus.dismissed) => Success(
        current.copyWith(
          status: ReminderStatus.dismissed,
          version: current.version + 1,
          updatedAt: transitionTime,
        ),
      ),

    // Any other transition is invalid.
    _ => Failure(InvalidStateTransition(current.status, target)),
  };
}
