import 'package:drift/drift.dart' hide Trigger;
import 'package:uuid/uuid.dart';

import '../../domain/entities/action.dart' as domain;
import '../../domain/entities/reminder.dart';
import '../../domain/entities/trigger.dart';
import '../../domain/entities/validated_reminder.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/delivery_status.dart';
import '../../domain/enums/intent_type.dart';
import '../../domain/enums/reminder_status.dart';
import '../../domain/enums/trigger_type.dart';
import '../database/database.dart';
import 'reminder_repository.dart';

/// Drift-backed SQLite implementation of [ReminderRepository].
class ReminderRepositoryImpl implements ReminderRepository {
  final AppDatabase db;
  final Uuid _uuid;

  ReminderRepositoryImpl(this.db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  @override
  Future<Reminder> insert(ValidatedReminder reminder) async {
    final reminderId = _uuid.v4();
    final triggerId = _uuid.v4();
    final actionId = _uuid.v4();
    final now = DateTime.now().toUtc();

    final domainActionType = switch (reminder.intentType) {
      IntentType.call => ActionType.call,
      IntentType.text => ActionType.text,
      IntentType.email => ActionType.email,
      IntentType.openUrl => ActionType.openUrl,
      IntentType.general => ActionType.general,
    };

    final trigger = Trigger(
      id: triggerId,
      reminderId: reminderId,
      triggerType: TriggerType.scheduledTime,
      scheduledTimeUtc: reminder.scheduledTime.toUtc(),
      scheduledTimeTimezone: reminder.timezone,
      notificationScheduled: false,
      deliveryStatus: DeliveryStatus.scheduled,
    );

    final domainAction = domain.Action(
      id: actionId,
      reminderId: reminderId,
      actionType: domainActionType,
      targetValue: reminder.validatedUrl ?? reminder.phoneNumber,
      contactName: reminder.resolvedContact?.displayName,
      contactPhone: reminder.resolvedContact?.phoneNumber ?? reminder.phoneNumber,
      contactId: reminder.resolvedContact?.platformId,
    );

    final createdReminder = Reminder(
      id: reminderId,
      title: reminder.title,
      notes: reminder.notes,
      intentType: reminder.intentType,
      status: ReminderStatus.pending,
      snoozeCount: 0,
      snoozeDurationMinutes: 10,
      version: 1,
      originalTranscript: reminder.originalTranscript,
      createdAt: now,
      updatedAt: now,
      trigger: trigger,
      action: domainAction,
    );

    return insertRaw(createdReminder, trigger, domainAction);
  }

  @override
  Future<Reminder> insertRaw(Reminder reminder, Trigger trigger, domain.Action? action) async {
    return db.transaction(() async {
      await db.into(db.reminderTable).insert(
            ReminderTableCompanion.insert(
              id: reminder.id,
              title: reminder.title,
              notes: Value(reminder.notes),
              intentType: reminder.intentType.value,
              status: Value(reminder.status.value),
              snoozeCount: Value(reminder.snoozeCount),
              snoozeDurationMinutes: Value(reminder.snoozeDurationMinutes),
              parentReminderId: Value(reminder.parentReminderId),
              depth: Value(reminder.depth),
              version: Value(reminder.version),
              originalTranscript: Value(reminder.originalTranscript),
              createdAt: reminder.createdAt.toUtc().toIso8601String(),
              updatedAt: reminder.updatedAt.toUtc().toIso8601String(),
              completedAt: Value(reminder.completedAt?.toUtc().toIso8601String()),
              isDeleted: Value(reminder.isDeleted ? 1 : 0),
              deletedAt: Value(reminder.deletedAt?.toUtc().toIso8601String()),
            ),
          );

      await db.into(db.triggerTable).insert(
            TriggerTableCompanion.insert(
              id: trigger.id,
              reminderId: trigger.reminderId,
              triggerType: trigger.triggerType.value,
              scheduledTimeUtc: trigger.scheduledTimeUtc.toUtc().toIso8601String(),
              scheduledTimeTimezone: Value(trigger.scheduledTimeTimezone),
              notificationScheduled: Value(trigger.notificationScheduled ? 1 : 0),
              notificationId: Value(trigger.notificationId),
              firedAt: Value(trigger.firedAt?.toUtc().toIso8601String()),
              deliveryStatus: Value(trigger.deliveryStatus.value),
              recurrenceRule: Value(trigger.recurrenceRule),
            ),
          );

      if (action != null) {
        await db.into(db.actionTable).insert(
              ActionTableCompanion.insert(
                id: action.id,
                reminderId: action.reminderId,
                actionType: action.actionType.value,
                targetValue: Value(action.targetValue),
                contactName: Value(action.contactName),
                contactPhone: Value(action.contactPhone),
                contactId: Value(action.contactId),
              ),
            );
      }

      return reminder.copyWith(trigger: trigger, action: action);
    });
  }

  @override
  Future<Reminder> update(Reminder reminder, {required int expectedVersion}) async {
    final now = DateTime.now().toUtc();
    final newVersion = expectedVersion + 1;

    final affected = await (db.update(db.reminderTable)
          ..where((t) => t.id.equals(reminder.id) & t.version.equals(expectedVersion)))
        .write(
      ReminderTableCompanion(
        title: Value(reminder.title),
        notes: Value(reminder.notes),
        intentType: Value(reminder.intentType.value),
        status: Value(reminder.status.value),
        snoozeCount: Value(reminder.snoozeCount),
        snoozeDurationMinutes: Value(reminder.snoozeDurationMinutes),
        version: Value(newVersion),
        updatedAt: Value(now.toIso8601String()),
        completedAt: Value(reminder.completedAt?.toUtc().toIso8601String()),
        isDeleted: Value(reminder.isDeleted ? 1 : 0),
        deletedAt: Value(reminder.deletedAt?.toUtc().toIso8601String()),
      ),
    );

    if (affected == 1) {
      if (reminder.trigger != null) {
        await updateTrigger(reminder.trigger!);
      }
      return reminder.copyWith(version: newVersion, updatedAt: now);
    }

    // Retry once with re-reading current state per ARCHITECTURE.md §8.2
    final current = await getById(reminder.id);
    if (current == null) {
      throw OptimisticLockException(reminder.id, expectedVersion);
    }

    final retryVersion = current.version + 1;
    final retryAffected = await (db.update(db.reminderTable)
          ..where((t) => t.id.equals(reminder.id) & t.version.equals(current.version)))
        .write(
      ReminderTableCompanion(
        title: Value(reminder.title),
        notes: Value(reminder.notes),
        intentType: Value(reminder.intentType.value),
        status: Value(reminder.status.value),
        snoozeCount: Value(reminder.snoozeCount),
        snoozeDurationMinutes: Value(reminder.snoozeDurationMinutes),
        version: Value(retryVersion),
        updatedAt: Value(now.toIso8601String()),
        completedAt: Value(reminder.completedAt?.toUtc().toIso8601String()),
        isDeleted: Value(reminder.isDeleted ? 1 : 0),
        deletedAt: Value(reminder.deletedAt?.toUtc().toIso8601String()),
      ),
    );

    if (retryAffected == 1) {
      if (reminder.trigger != null) {
        await updateTrigger(reminder.trigger!);
      }
      return reminder.copyWith(version: retryVersion, updatedAt: now);
    }

    throw OptimisticLockException(reminder.id, expectedVersion);
  }

  @override
  Future<int> transitionState(
    String id,
    int expectedVersion,
    ReminderStatus newStatus, {
    DateTime? completedAt,
    DateTime? updatedAt,
  }) async {
    final now = (updatedAt ?? DateTime.now()).toUtc();
    final compTime = (newStatus == ReminderStatus.completed) ? (completedAt ?? now).toUtc() : null;

    final affected =
        await (db.update(db.reminderTable)..where((t) => t.id.equals(id) & t.version.equals(expectedVersion))).write(
      ReminderTableCompanion(
        status: Value(newStatus.value),
        version: Value(expectedVersion + 1),
        updatedAt: Value(now.toIso8601String()),
        completedAt: Value(compTime?.toIso8601String()),
      ),
    );

    return affected;
  }

  @override
  Future<void> softDelete(String id, int expectedVersion) async {
    final now = DateTime.now().toUtc();
    final affected =
        await (db.update(db.reminderTable)..where((t) => t.id.equals(id) & t.version.equals(expectedVersion))).write(
      ReminderTableCompanion(
        isDeleted: const Value(1),
        deletedAt: Value(now.toIso8601String()),
        version: Value(expectedVersion + 1),
        updatedAt: Value(now.toIso8601String()),
      ),
    );

    if (affected == 0) {
      throw OptimisticLockException(id, expectedVersion);
    }
  }

  @override
  Future<Reminder?> getById(String id) async {
    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(db.reminderTable.id.equals(id));

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return _mapRowToReminder(rows.first);
  }

  @override
  Future<List<Reminder>> getPending({DateTime? before}) async {
    var query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) &
            (db.reminderTable.status.equals('PENDING') | db.reminderTable.status.equals('SNOOZED')),
      );

    if (before != null) {
      query = query..where(db.triggerTable.scheduledTimeUtc.isSmallerOrEqualValue(before.toUtc().toIso8601String()));
    }

    query = query..orderBy([OrderingTerm.asc(db.triggerTable.scheduledTimeUtc)]);

    final rows = await query.get();
    return rows.map(_mapRowToReminder).toList();
  }

  @override
  Future<List<Reminder>> getOverdue(DateTime now) async {
    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) &
            (db.reminderTable.status.equals('PENDING') | db.reminderTable.status.equals('SNOOZED')) &
            db.triggerTable.scheduledTimeUtc.isSmallerOrEqualValue(now.toUtc().toIso8601String()),
      )
      ..orderBy([OrderingTerm.asc(db.triggerTable.scheduledTimeUtc)]);

    final rows = await query.get();
    return rows.map(_mapRowToReminder).toList();
  }

  @override
  Future<List<Reminder>> getByTimeRange(DateTime start, DateTime end) async {
    final startIso = start.toUtc().toIso8601String();
    final endIso = end.toUtc().toIso8601String();

    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) &
            db.triggerTable.scheduledTimeUtc.isBiggerOrEqualValue(startIso) &
            db.triggerTable.scheduledTimeUtc.isSmallerOrEqualValue(endIso),
      )
      ..orderBy([OrderingTerm.asc(db.triggerTable.scheduledTimeUtc)]);

    final rows = await query.get();
    return rows.map(_mapRowToReminder).toList();
  }

  @override
  Future<List<Reminder>> getPendingSortedByTime({int? limit}) async {
    var query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) &
            (db.reminderTable.status.equals('PENDING') | db.reminderTable.status.equals('SNOOZED')),
      )
      ..orderBy([OrderingTerm.asc(db.triggerTable.scheduledTimeUtc)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    final rows = await query.get();
    return rows.map(_mapRowToReminder).toList();
  }

  @override
  Future<List<Reminder>> getConflicting(DateTime scheduledTime, {int windowMinutes = 15}) async {
    final startUtc = scheduledTime.subtract(Duration(minutes: windowMinutes)).toUtc().toIso8601String();
    final endUtc = scheduledTime.add(Duration(minutes: windowMinutes)).toUtc().toIso8601String();

    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) &
            (db.reminderTable.status.equals('PENDING') | db.reminderTable.status.equals('SNOOZED')) &
            db.triggerTable.scheduledTimeUtc.isBiggerOrEqualValue(startUtc) &
            db.triggerTable.scheduledTimeUtc.isSmallerOrEqualValue(endUtc),
      );

    final rows = await query.get();
    return rows.map(_mapRowToReminder).toList();
  }

  @override
  Future<List<Reminder>> getByNotificationId(int notificationId) async {
    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) & db.triggerTable.notificationId.equals(notificationId),
      );

    final rows = await query.get();
    return rows.map(_mapRowToReminder).toList();
  }

  @override
  Stream<List<Reminder>> watchPending() {
    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) &
            (db.reminderTable.status.equals('PENDING') | db.reminderTable.status.equals('SNOOZED')),
      )
      ..orderBy([OrderingTerm.asc(db.triggerTable.scheduledTimeUtc)]);

    return query.watch().map((rows) => rows.map(_mapRowToReminder).toList());
  }

  @override
  Stream<List<Reminder>> watchOverdue(DateTime now) {
    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(
        db.reminderTable.isDeleted.equals(0) &
            (db.reminderTable.status.equals('PENDING') | db.reminderTable.status.equals('SNOOZED')) &
            db.triggerTable.scheduledTimeUtc.isSmallerOrEqualValue(now.toUtc().toIso8601String()),
      )
      ..orderBy([OrderingTerm.asc(db.triggerTable.scheduledTimeUtc)]);

    return query.watch().map((rows) => rows.map(_mapRowToReminder).toList());
  }

  @override
  Future<void> updateTriggerScheduling(String reminderId, bool scheduled, int? notificationId) async {
    await (db.update(db.triggerTable)..where((t) => t.reminderId.equals(reminderId))).write(
      TriggerTableCompanion(
        notificationScheduled: Value(scheduled ? 1 : 0),
        notificationId: Value(notificationId),
      ),
    );
  }

  @override
  Future<void> updateTriggerDeliveryStatus(String reminderId, DeliveryStatus status) async {
    await (db.update(db.triggerTable)..where((t) => t.reminderId.equals(reminderId))).write(
      TriggerTableCompanion(
        deliveryStatus: Value(status.value),
      ),
    );
  }

  @override
  Future<void> updateTriggerFiredAt(String reminderId, DateTime firedAt) async {
    await (db.update(db.triggerTable)..where((t) => t.reminderId.equals(reminderId))).write(
      TriggerTableCompanion(
        firedAt: Value(firedAt.toUtc().toIso8601String()),
      ),
    );
  }

  Future<void> updateTrigger(Trigger trigger) async {
    await (db.update(db.triggerTable)..where((t) => t.reminderId.equals(trigger.reminderId))).write(
      TriggerTableCompanion(
        triggerType: Value(trigger.triggerType.value),
        scheduledTimeUtc: Value(trigger.scheduledTimeUtc.toUtc().toIso8601String()),
        scheduledTimeTimezone: Value(trigger.scheduledTimeTimezone),
        notificationScheduled: Value(trigger.notificationScheduled ? 1 : 0),
        notificationId: Value(trigger.notificationId),
        firedAt: Value(trigger.firedAt?.toUtc().toIso8601String()),
        deliveryStatus: Value(trigger.deliveryStatus.value),
        recurrenceRule: Value(trigger.recurrenceRule),
      ),
    );
  }

  @override
  Future<Trigger?> findTriggerByReminderId(String reminderId) async {
    final query = db.select(db.triggerTable)..where((t) => t.reminderId.equals(reminderId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _mapTriggerEntry(row);
  }

  @override
  Future<domain.Action?> findActionByReminderId(String reminderId) async {
    final query = db.select(db.actionTable)..where((t) => t.reminderId.equals(reminderId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _mapActionEntry(row);
  }

  @override
  Stream<List<Reminder>> watchAll() {
    final query = db.select(db.reminderTable).join([
      leftOuterJoin(db.triggerTable, db.triggerTable.reminderId.equalsExp(db.reminderTable.id)),
      leftOuterJoin(db.actionTable, db.actionTable.reminderId.equalsExp(db.reminderTable.id)),
    ])
      ..where(db.reminderTable.isDeleted.equals(0));

    return query.watch().map((rows) => rows.map(_mapRowToReminder).toList());
  }

  @override
  Future<int> hardDeleteOlderThan(DateTime cutoff) async {
    final cutoffIso = cutoff.toUtc().toIso8601String();
    return db.transaction(() async {
      final oldReminders = await (db.select(db.reminderTable)
            ..where((t) => t.isDeleted.equals(1) & t.deletedAt.isSmallerOrEqualValue(cutoffIso)))
          .get();
      final ids = oldReminders.map((r) => r.id).toList();
      if (ids.isEmpty) return 0;
      await (db.delete(db.triggerTable)..where((t) => t.reminderId.isIn(ids))).go();
      await (db.delete(db.actionTable)..where((t) => t.reminderId.isIn(ids))).go();
      return (db.delete(db.reminderTable)..where((t) => t.id.isIn(ids))).go();
    });
  }

  @override
  Future<String?> getMetadata(String key) async {
    final query = db.select(db.appMetadataTable)..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> setMetadata(String key, String value) async {
    await db.into(db.appMetadataTable).insertOnConflictUpdate(
          AppMetadataTableCompanion.insert(key: key, value: value),
        );
  }

  Reminder _mapRowToReminder(TypedResult row) {
    final r = row.readTable(db.reminderTable);
    final t = row.readTableOrNull(db.triggerTable);
    final a = row.readTableOrNull(db.actionTable);

    return Reminder(
      id: r.id,
      title: r.title,
      notes: r.notes,
      intentType: IntentType.fromValue(r.intentType),
      status: ReminderStatus.fromValue(r.status),
      snoozeCount: r.snoozeCount,
      snoozeDurationMinutes: r.snoozeDurationMinutes,
      parentReminderId: r.parentReminderId,
      depth: r.depth,
      version: r.version,
      originalTranscript: r.originalTranscript,
      createdAt: DateTime.parse(r.createdAt),
      updatedAt: DateTime.parse(r.updatedAt),
      completedAt: r.completedAt != null ? DateTime.parse(r.completedAt!) : null,
      isDeleted: r.isDeleted == 1,
      deletedAt: r.deletedAt != null ? DateTime.parse(r.deletedAt!) : null,
      trigger: t != null ? _mapTriggerEntry(t) : null,
      action: a != null ? _mapActionEntry(a) : null,
    );
  }

  Trigger _mapTriggerEntry(TriggerEntry t) {
    return Trigger(
      id: t.id,
      reminderId: t.reminderId,
      triggerType: TriggerType.fromValue(t.triggerType),
      scheduledTimeUtc: DateTime.parse(t.scheduledTimeUtc),
      scheduledTimeTimezone: t.scheduledTimeTimezone,
      notificationScheduled: t.notificationScheduled == 1,
      notificationId: t.notificationId,
      firedAt: t.firedAt != null ? DateTime.parse(t.firedAt!) : null,
      deliveryStatus: DeliveryStatus.fromValue(t.deliveryStatus),
      recurrenceRule: t.recurrenceRule,
    );
  }

  domain.Action _mapActionEntry(ActionEntry a) {
    return domain.Action(
      id: a.id,
      reminderId: a.reminderId,
      actionType: ActionType.fromValue(a.actionType),
      targetValue: a.targetValue,
      contactName: a.contactName,
      contactPhone: a.contactPhone,
      contactId: a.contactId,
    );
  }
}
