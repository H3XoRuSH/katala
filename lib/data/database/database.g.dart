// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ReminderTableTable extends ReminderTable with TableInfo<$ReminderTableTable, ReminderEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title =
      GeneratedColumn<String>('title', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes =
      GeneratedColumn<String>('notes', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _intentTypeMeta = const VerificationMeta('intentType');
  @override
  late final GeneratedColumn<String> intentType = GeneratedColumn<String>('intent_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL CHECK (intent_type IN (\'GENERAL\', \'CALL\', \'TEXT\', \'EMAIL\', \'OPEN_URL\'))');
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>('status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT \'PENDING\' CHECK (status IN (\'PENDING\', \'COMPLETED\', \'SNOOZED\', \'DISMISSED\'))',
      defaultValue: const CustomExpression('\'PENDING\''));
  static const VerificationMeta _snoozeCountMeta = const VerificationMeta('snoozeCount');
  @override
  late final GeneratedColumn<int> snoozeCount = GeneratedColumn<int>('snooze_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _snoozeDurationMinutesMeta = const VerificationMeta('snoozeDurationMinutes');
  @override
  late final GeneratedColumn<int> snoozeDurationMinutes = GeneratedColumn<int>(
      'snooze_duration_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 10',
      defaultValue: const CustomExpression('10'));
  static const VerificationMeta _parentReminderIdMeta = const VerificationMeta('parentReminderId');
  @override
  late final GeneratedColumn<String> parentReminderId = GeneratedColumn<String>('parent_reminder_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false, $customConstraints: 'REFERENCES reminder(id)');
  static const VerificationMeta _depthMeta = const VerificationMeta('depth');
  @override
  late final GeneratedColumn<int> depth = GeneratedColumn<int>('depth', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _versionMeta = const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>('version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 1',
      defaultValue: const CustomExpression('1'));
  static const VerificationMeta _originalTranscriptMeta = const VerificationMeta('originalTranscript');
  @override
  late final GeneratedColumn<String> originalTranscript = GeneratedColumn<String>(
      'original_transcript', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt =
      GeneratedColumn<String>('created_at', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt =
      GeneratedColumn<String>('updated_at', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta = const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>('completed_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta = const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<int> isDeleted = GeneratedColumn<int>('is_deleted', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<String> deletedAt =
      GeneratedColumn<String>('deleted_at', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        notes,
        intentType,
        status,
        snoozeCount,
        snoozeDurationMinutes,
        parentReminderId,
        depth,
        version,
        originalTranscript,
        createdAt,
        updatedAt,
        completedAt,
        isDeleted,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder';
  @override
  VerificationContext validateIntegrity(Insertable<ReminderEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('intent_type')) {
      context.handle(_intentTypeMeta, intentType.isAcceptableOrUnknown(data['intent_type']!, _intentTypeMeta));
    } else if (isInserting) {
      context.missing(_intentTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('snooze_count')) {
      context.handle(_snoozeCountMeta, snoozeCount.isAcceptableOrUnknown(data['snooze_count']!, _snoozeCountMeta));
    }
    if (data.containsKey('snooze_duration_minutes')) {
      context.handle(_snoozeDurationMinutesMeta,
          snoozeDurationMinutes.isAcceptableOrUnknown(data['snooze_duration_minutes']!, _snoozeDurationMinutesMeta));
    }
    if (data.containsKey('parent_reminder_id')) {
      context.handle(_parentReminderIdMeta,
          parentReminderId.isAcceptableOrUnknown(data['parent_reminder_id']!, _parentReminderIdMeta));
    }
    if (data.containsKey('depth')) {
      context.handle(_depthMeta, depth.isAcceptableOrUnknown(data['depth']!, _depthMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta, version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('original_transcript')) {
      context.handle(_originalTranscriptMeta,
          originalTranscript.isAcceptableOrUnknown(data['original_transcript']!, _originalTranscriptMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(_completedAtMeta, completedAt.isAcceptableOrUnknown(data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta, isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta, deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderEntry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes']),
      intentType: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}intent_type'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      snoozeCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}snooze_count'])!,
      snoozeDurationMinutes:
          attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}snooze_duration_minutes'])!,
      parentReminderId:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}parent_reminder_id']),
      depth: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}depth'])!,
      version: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      originalTranscript:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}original_transcript']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
      completedAt: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}completed_at']),
      isDeleted: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}is_deleted'])!,
      deletedAt: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ReminderTableTable createAlias(String alias) {
    return $ReminderTableTable(attachedDatabase, alias);
  }
}

class ReminderEntry extends DataClass implements Insertable<ReminderEntry> {
  final String id;
  final String title;
  final String? notes;
  final String intentType;
  final String status;
  final int snoozeCount;
  final int snoozeDurationMinutes;
  final String? parentReminderId;
  final int depth;
  final int version;
  final String? originalTranscript;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final int isDeleted;
  final String? deletedAt;
  const ReminderEntry(
      {required this.id,
      required this.title,
      this.notes,
      required this.intentType,
      required this.status,
      required this.snoozeCount,
      required this.snoozeDurationMinutes,
      this.parentReminderId,
      required this.depth,
      required this.version,
      this.originalTranscript,
      required this.createdAt,
      required this.updatedAt,
      this.completedAt,
      required this.isDeleted,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['intent_type'] = Variable<String>(intentType);
    map['status'] = Variable<String>(status);
    map['snooze_count'] = Variable<int>(snoozeCount);
    map['snooze_duration_minutes'] = Variable<int>(snoozeDurationMinutes);
    if (!nullToAbsent || parentReminderId != null) {
      map['parent_reminder_id'] = Variable<String>(parentReminderId);
    }
    map['depth'] = Variable<int>(depth);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || originalTranscript != null) {
      map['original_transcript'] = Variable<String>(originalTranscript);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    map['is_deleted'] = Variable<int>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  ReminderTableCompanion toCompanion(bool nullToAbsent) {
    return ReminderTableCompanion(
      id: Value(id),
      title: Value(title),
      notes: notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      intentType: Value(intentType),
      status: Value(status),
      snoozeCount: Value(snoozeCount),
      snoozeDurationMinutes: Value(snoozeDurationMinutes),
      parentReminderId: parentReminderId == null && nullToAbsent ? const Value.absent() : Value(parentReminderId),
      depth: Value(depth),
      version: Value(version),
      originalTranscript: originalTranscript == null && nullToAbsent ? const Value.absent() : Value(originalTranscript),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent ? const Value.absent() : Value(completedAt),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
    );
  }

  factory ReminderEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderEntry(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      intentType: serializer.fromJson<String>(json['intentType']),
      status: serializer.fromJson<String>(json['status']),
      snoozeCount: serializer.fromJson<int>(json['snoozeCount']),
      snoozeDurationMinutes: serializer.fromJson<int>(json['snoozeDurationMinutes']),
      parentReminderId: serializer.fromJson<String?>(json['parentReminderId']),
      depth: serializer.fromJson<int>(json['depth']),
      version: serializer.fromJson<int>(json['version']),
      originalTranscript: serializer.fromJson<String?>(json['originalTranscript']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      isDeleted: serializer.fromJson<int>(json['isDeleted']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'intentType': serializer.toJson<String>(intentType),
      'status': serializer.toJson<String>(status),
      'snoozeCount': serializer.toJson<int>(snoozeCount),
      'snoozeDurationMinutes': serializer.toJson<int>(snoozeDurationMinutes),
      'parentReminderId': serializer.toJson<String?>(parentReminderId),
      'depth': serializer.toJson<int>(depth),
      'version': serializer.toJson<int>(version),
      'originalTranscript': serializer.toJson<String?>(originalTranscript),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'isDeleted': serializer.toJson<int>(isDeleted),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  ReminderEntry copyWith(
          {String? id,
          String? title,
          Value<String?> notes = const Value.absent(),
          String? intentType,
          String? status,
          int? snoozeCount,
          int? snoozeDurationMinutes,
          Value<String?> parentReminderId = const Value.absent(),
          int? depth,
          int? version,
          Value<String?> originalTranscript = const Value.absent(),
          String? createdAt,
          String? updatedAt,
          Value<String?> completedAt = const Value.absent(),
          int? isDeleted,
          Value<String?> deletedAt = const Value.absent()}) =>
      ReminderEntry(
        id: id ?? this.id,
        title: title ?? this.title,
        notes: notes.present ? notes.value : this.notes,
        intentType: intentType ?? this.intentType,
        status: status ?? this.status,
        snoozeCount: snoozeCount ?? this.snoozeCount,
        snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
        parentReminderId: parentReminderId.present ? parentReminderId.value : this.parentReminderId,
        depth: depth ?? this.depth,
        version: version ?? this.version,
        originalTranscript: originalTranscript.present ? originalTranscript.value : this.originalTranscript,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  ReminderEntry copyWithCompanion(ReminderTableCompanion data) {
    return ReminderEntry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      intentType: data.intentType.present ? data.intentType.value : this.intentType,
      status: data.status.present ? data.status.value : this.status,
      snoozeCount: data.snoozeCount.present ? data.snoozeCount.value : this.snoozeCount,
      snoozeDurationMinutes:
          data.snoozeDurationMinutes.present ? data.snoozeDurationMinutes.value : this.snoozeDurationMinutes,
      parentReminderId: data.parentReminderId.present ? data.parentReminderId.value : this.parentReminderId,
      depth: data.depth.present ? data.depth.value : this.depth,
      version: data.version.present ? data.version.value : this.version,
      originalTranscript: data.originalTranscript.present ? data.originalTranscript.value : this.originalTranscript,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present ? data.completedAt.value : this.completedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderEntry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('intentType: $intentType, ')
          ..write('status: $status, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('snoozeDurationMinutes: $snoozeDurationMinutes, ')
          ..write('parentReminderId: $parentReminderId, ')
          ..write('depth: $depth, ')
          ..write('version: $version, ')
          ..write('originalTranscript: $originalTranscript, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, notes, intentType, status, snoozeCount, snoozeDurationMinutes,
      parentReminderId, depth, version, originalTranscript, createdAt, updatedAt, completedAt, isDeleted, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderEntry &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.intentType == this.intentType &&
          other.status == this.status &&
          other.snoozeCount == this.snoozeCount &&
          other.snoozeDurationMinutes == this.snoozeDurationMinutes &&
          other.parentReminderId == this.parentReminderId &&
          other.depth == this.depth &&
          other.version == this.version &&
          other.originalTranscript == this.originalTranscript &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt);
}

class ReminderTableCompanion extends UpdateCompanion<ReminderEntry> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> notes;
  final Value<String> intentType;
  final Value<String> status;
  final Value<int> snoozeCount;
  final Value<int> snoozeDurationMinutes;
  final Value<String?> parentReminderId;
  final Value<int> depth;
  final Value<int> version;
  final Value<String?> originalTranscript;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String?> completedAt;
  final Value<int> isDeleted;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const ReminderTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.intentType = const Value.absent(),
    this.status = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.snoozeDurationMinutes = const Value.absent(),
    this.parentReminderId = const Value.absent(),
    this.depth = const Value.absent(),
    this.version = const Value.absent(),
    this.originalTranscript = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderTableCompanion.insert({
    required String id,
    required String title,
    this.notes = const Value.absent(),
    required String intentType,
    this.status = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.snoozeDurationMinutes = const Value.absent(),
    this.parentReminderId = const Value.absent(),
    this.depth = const Value.absent(),
    this.version = const Value.absent(),
    this.originalTranscript = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.completedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        intentType = Value(intentType),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ReminderEntry> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? intentType,
    Expression<String>? status,
    Expression<int>? snoozeCount,
    Expression<int>? snoozeDurationMinutes,
    Expression<String>? parentReminderId,
    Expression<int>? depth,
    Expression<int>? version,
    Expression<String>? originalTranscript,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? completedAt,
    Expression<int>? isDeleted,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (intentType != null) 'intent_type': intentType,
      if (status != null) 'status': status,
      if (snoozeCount != null) 'snooze_count': snoozeCount,
      if (snoozeDurationMinutes != null) 'snooze_duration_minutes': snoozeDurationMinutes,
      if (parentReminderId != null) 'parent_reminder_id': parentReminderId,
      if (depth != null) 'depth': depth,
      if (version != null) 'version': version,
      if (originalTranscript != null) 'original_transcript': originalTranscript,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String?>? notes,
      Value<String>? intentType,
      Value<String>? status,
      Value<int>? snoozeCount,
      Value<int>? snoozeDurationMinutes,
      Value<String?>? parentReminderId,
      Value<int>? depth,
      Value<int>? version,
      Value<String?>? originalTranscript,
      Value<String>? createdAt,
      Value<String>? updatedAt,
      Value<String?>? completedAt,
      Value<int>? isDeleted,
      Value<String?>? deletedAt,
      Value<int>? rowid}) {
    return ReminderTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      intentType: intentType ?? this.intentType,
      status: status ?? this.status,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      parentReminderId: parentReminderId ?? this.parentReminderId,
      depth: depth ?? this.depth,
      version: version ?? this.version,
      originalTranscript: originalTranscript ?? this.originalTranscript,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (intentType.present) {
      map['intent_type'] = Variable<String>(intentType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (snoozeCount.present) {
      map['snooze_count'] = Variable<int>(snoozeCount.value);
    }
    if (snoozeDurationMinutes.present) {
      map['snooze_duration_minutes'] = Variable<int>(snoozeDurationMinutes.value);
    }
    if (parentReminderId.present) {
      map['parent_reminder_id'] = Variable<String>(parentReminderId.value);
    }
    if (depth.present) {
      map['depth'] = Variable<int>(depth.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (originalTranscript.present) {
      map['original_transcript'] = Variable<String>(originalTranscript.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<int>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('intentType: $intentType, ')
          ..write('status: $status, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('snoozeDurationMinutes: $snoozeDurationMinutes, ')
          ..write('parentReminderId: $parentReminderId, ')
          ..write('depth: $depth, ')
          ..write('version: $version, ')
          ..write('originalTranscript: $originalTranscript, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TriggerTableTable extends TriggerTable with TableInfo<$TriggerTableTable, TriggerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TriggerTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reminderIdMeta = const VerificationMeta('reminderId');
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>('reminder_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE REFERENCES reminder(id)');
  static const VerificationMeta _triggerTypeMeta = const VerificationMeta('triggerType');
  @override
  late final GeneratedColumn<String> triggerType = GeneratedColumn<String>('trigger_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL CHECK (trigger_type IN (\'SCHEDULED_TIME\', \'GEOFENCE\'))');
  static const VerificationMeta _scheduledTimeUtcMeta = const VerificationMeta('scheduledTimeUtc');
  @override
  late final GeneratedColumn<String> scheduledTimeUtc = GeneratedColumn<String>(
      'scheduled_time_utc', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scheduledTimeTimezoneMeta = const VerificationMeta('scheduledTimeTimezone');
  @override
  late final GeneratedColumn<String> scheduledTimeTimezone = GeneratedColumn<String>(
      'scheduled_time_timezone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT \'UTC\'',
      defaultValue: const CustomExpression('\'UTC\''));
  static const VerificationMeta _notificationScheduledMeta = const VerificationMeta('notificationScheduled');
  @override
  late final GeneratedColumn<int> notificationScheduled = GeneratedColumn<int>(
      'notification_scheduled', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _notificationIdMeta = const VerificationMeta('notificationId');
  @override
  late final GeneratedColumn<int> notificationId =
      GeneratedColumn<int>('notification_id', aliasedName, true, type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _firedAtMeta = const VerificationMeta('firedAt');
  @override
  late final GeneratedColumn<String> firedAt =
      GeneratedColumn<String>('fired_at', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deliveryStatusMeta = const VerificationMeta('deliveryStatus');
  @override
  late final GeneratedColumn<String> deliveryStatus = GeneratedColumn<String>('delivery_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints:
          'NOT NULL DEFAULT \'scheduled\' CHECK (delivery_status IN (\'scheduled\', \'delivery_uncertain\', \'delivery_missed\'))',
      defaultValue: const CustomExpression('\'scheduled\''));
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta('recurrenceRule');
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>('recurrence_rule', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        reminderId,
        triggerType,
        scheduledTimeUtc,
        scheduledTimeTimezone,
        notificationScheduled,
        notificationId,
        firedAt,
        deliveryStatus,
        recurrenceRule
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trigger_';
  @override
  VerificationContext validateIntegrity(Insertable<TriggerEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('reminder_id')) {
      context.handle(_reminderIdMeta, reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta));
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('trigger_type')) {
      context.handle(_triggerTypeMeta, triggerType.isAcceptableOrUnknown(data['trigger_type']!, _triggerTypeMeta));
    } else if (isInserting) {
      context.missing(_triggerTypeMeta);
    }
    if (data.containsKey('scheduled_time_utc')) {
      context.handle(_scheduledTimeUtcMeta,
          scheduledTimeUtc.isAcceptableOrUnknown(data['scheduled_time_utc']!, _scheduledTimeUtcMeta));
    } else if (isInserting) {
      context.missing(_scheduledTimeUtcMeta);
    }
    if (data.containsKey('scheduled_time_timezone')) {
      context.handle(_scheduledTimeTimezoneMeta,
          scheduledTimeTimezone.isAcceptableOrUnknown(data['scheduled_time_timezone']!, _scheduledTimeTimezoneMeta));
    }
    if (data.containsKey('notification_scheduled')) {
      context.handle(_notificationScheduledMeta,
          notificationScheduled.isAcceptableOrUnknown(data['notification_scheduled']!, _notificationScheduledMeta));
    }
    if (data.containsKey('notification_id')) {
      context.handle(
          _notificationIdMeta, notificationId.isAcceptableOrUnknown(data['notification_id']!, _notificationIdMeta));
    }
    if (data.containsKey('fired_at')) {
      context.handle(_firedAtMeta, firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta));
    }
    if (data.containsKey('delivery_status')) {
      context.handle(
          _deliveryStatusMeta, deliveryStatus.isAcceptableOrUnknown(data['delivery_status']!, _deliveryStatusMeta));
    }
    if (data.containsKey('recurrence_rule')) {
      context.handle(
          _recurrenceRuleMeta, recurrenceRule.isAcceptableOrUnknown(data['recurrence_rule']!, _recurrenceRuleMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TriggerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TriggerEntry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      reminderId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}reminder_id'])!,
      triggerType: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}trigger_type'])!,
      scheduledTimeUtc:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}scheduled_time_utc'])!,
      scheduledTimeTimezone:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}scheduled_time_timezone'])!,
      notificationScheduled:
          attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}notification_scheduled'])!,
      notificationId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}notification_id']),
      firedAt: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fired_at']),
      deliveryStatus:
          attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}delivery_status'])!,
      recurrenceRule: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}recurrence_rule']),
    );
  }

  @override
  $TriggerTableTable createAlias(String alias) {
    return $TriggerTableTable(attachedDatabase, alias);
  }
}

class TriggerEntry extends DataClass implements Insertable<TriggerEntry> {
  final String id;
  final String reminderId;
  final String triggerType;
  final String scheduledTimeUtc;
  final String scheduledTimeTimezone;
  final int notificationScheduled;
  final int? notificationId;
  final String? firedAt;
  final String deliveryStatus;
  final String? recurrenceRule;
  const TriggerEntry(
      {required this.id,
      required this.reminderId,
      required this.triggerType,
      required this.scheduledTimeUtc,
      required this.scheduledTimeTimezone,
      required this.notificationScheduled,
      this.notificationId,
      this.firedAt,
      required this.deliveryStatus,
      this.recurrenceRule});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['reminder_id'] = Variable<String>(reminderId);
    map['trigger_type'] = Variable<String>(triggerType);
    map['scheduled_time_utc'] = Variable<String>(scheduledTimeUtc);
    map['scheduled_time_timezone'] = Variable<String>(scheduledTimeTimezone);
    map['notification_scheduled'] = Variable<int>(notificationScheduled);
    if (!nullToAbsent || notificationId != null) {
      map['notification_id'] = Variable<int>(notificationId);
    }
    if (!nullToAbsent || firedAt != null) {
      map['fired_at'] = Variable<String>(firedAt);
    }
    map['delivery_status'] = Variable<String>(deliveryStatus);
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule);
    }
    return map;
  }

  TriggerTableCompanion toCompanion(bool nullToAbsent) {
    return TriggerTableCompanion(
      id: Value(id),
      reminderId: Value(reminderId),
      triggerType: Value(triggerType),
      scheduledTimeUtc: Value(scheduledTimeUtc),
      scheduledTimeTimezone: Value(scheduledTimeTimezone),
      notificationScheduled: Value(notificationScheduled),
      notificationId: notificationId == null && nullToAbsent ? const Value.absent() : Value(notificationId),
      firedAt: firedAt == null && nullToAbsent ? const Value.absent() : Value(firedAt),
      deliveryStatus: Value(deliveryStatus),
      recurrenceRule: recurrenceRule == null && nullToAbsent ? const Value.absent() : Value(recurrenceRule),
    );
  }

  factory TriggerEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TriggerEntry(
      id: serializer.fromJson<String>(json['id']),
      reminderId: serializer.fromJson<String>(json['reminderId']),
      triggerType: serializer.fromJson<String>(json['triggerType']),
      scheduledTimeUtc: serializer.fromJson<String>(json['scheduledTimeUtc']),
      scheduledTimeTimezone: serializer.fromJson<String>(json['scheduledTimeTimezone']),
      notificationScheduled: serializer.fromJson<int>(json['notificationScheduled']),
      notificationId: serializer.fromJson<int?>(json['notificationId']),
      firedAt: serializer.fromJson<String?>(json['firedAt']),
      deliveryStatus: serializer.fromJson<String>(json['deliveryStatus']),
      recurrenceRule: serializer.fromJson<String?>(json['recurrenceRule']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'reminderId': serializer.toJson<String>(reminderId),
      'triggerType': serializer.toJson<String>(triggerType),
      'scheduledTimeUtc': serializer.toJson<String>(scheduledTimeUtc),
      'scheduledTimeTimezone': serializer.toJson<String>(scheduledTimeTimezone),
      'notificationScheduled': serializer.toJson<int>(notificationScheduled),
      'notificationId': serializer.toJson<int?>(notificationId),
      'firedAt': serializer.toJson<String?>(firedAt),
      'deliveryStatus': serializer.toJson<String>(deliveryStatus),
      'recurrenceRule': serializer.toJson<String?>(recurrenceRule),
    };
  }

  TriggerEntry copyWith(
          {String? id,
          String? reminderId,
          String? triggerType,
          String? scheduledTimeUtc,
          String? scheduledTimeTimezone,
          int? notificationScheduled,
          Value<int?> notificationId = const Value.absent(),
          Value<String?> firedAt = const Value.absent(),
          String? deliveryStatus,
          Value<String?> recurrenceRule = const Value.absent()}) =>
      TriggerEntry(
        id: id ?? this.id,
        reminderId: reminderId ?? this.reminderId,
        triggerType: triggerType ?? this.triggerType,
        scheduledTimeUtc: scheduledTimeUtc ?? this.scheduledTimeUtc,
        scheduledTimeTimezone: scheduledTimeTimezone ?? this.scheduledTimeTimezone,
        notificationScheduled: notificationScheduled ?? this.notificationScheduled,
        notificationId: notificationId.present ? notificationId.value : this.notificationId,
        firedAt: firedAt.present ? firedAt.value : this.firedAt,
        deliveryStatus: deliveryStatus ?? this.deliveryStatus,
        recurrenceRule: recurrenceRule.present ? recurrenceRule.value : this.recurrenceRule,
      );
  TriggerEntry copyWithCompanion(TriggerTableCompanion data) {
    return TriggerEntry(
      id: data.id.present ? data.id.value : this.id,
      reminderId: data.reminderId.present ? data.reminderId.value : this.reminderId,
      triggerType: data.triggerType.present ? data.triggerType.value : this.triggerType,
      scheduledTimeUtc: data.scheduledTimeUtc.present ? data.scheduledTimeUtc.value : this.scheduledTimeUtc,
      scheduledTimeTimezone:
          data.scheduledTimeTimezone.present ? data.scheduledTimeTimezone.value : this.scheduledTimeTimezone,
      notificationScheduled:
          data.notificationScheduled.present ? data.notificationScheduled.value : this.notificationScheduled,
      notificationId: data.notificationId.present ? data.notificationId.value : this.notificationId,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
      deliveryStatus: data.deliveryStatus.present ? data.deliveryStatus.value : this.deliveryStatus,
      recurrenceRule: data.recurrenceRule.present ? data.recurrenceRule.value : this.recurrenceRule,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TriggerEntry(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('triggerType: $triggerType, ')
          ..write('scheduledTimeUtc: $scheduledTimeUtc, ')
          ..write('scheduledTimeTimezone: $scheduledTimeTimezone, ')
          ..write('notificationScheduled: $notificationScheduled, ')
          ..write('notificationId: $notificationId, ')
          ..write('firedAt: $firedAt, ')
          ..write('deliveryStatus: $deliveryStatus, ')
          ..write('recurrenceRule: $recurrenceRule')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, reminderId, triggerType, scheduledTimeUtc, scheduledTimeTimezone,
      notificationScheduled, notificationId, firedAt, deliveryStatus, recurrenceRule);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TriggerEntry &&
          other.id == this.id &&
          other.reminderId == this.reminderId &&
          other.triggerType == this.triggerType &&
          other.scheduledTimeUtc == this.scheduledTimeUtc &&
          other.scheduledTimeTimezone == this.scheduledTimeTimezone &&
          other.notificationScheduled == this.notificationScheduled &&
          other.notificationId == this.notificationId &&
          other.firedAt == this.firedAt &&
          other.deliveryStatus == this.deliveryStatus &&
          other.recurrenceRule == this.recurrenceRule);
}

class TriggerTableCompanion extends UpdateCompanion<TriggerEntry> {
  final Value<String> id;
  final Value<String> reminderId;
  final Value<String> triggerType;
  final Value<String> scheduledTimeUtc;
  final Value<String> scheduledTimeTimezone;
  final Value<int> notificationScheduled;
  final Value<int?> notificationId;
  final Value<String?> firedAt;
  final Value<String> deliveryStatus;
  final Value<String?> recurrenceRule;
  final Value<int> rowid;
  const TriggerTableCompanion({
    this.id = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.triggerType = const Value.absent(),
    this.scheduledTimeUtc = const Value.absent(),
    this.scheduledTimeTimezone = const Value.absent(),
    this.notificationScheduled = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.deliveryStatus = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TriggerTableCompanion.insert({
    required String id,
    required String reminderId,
    required String triggerType,
    required String scheduledTimeUtc,
    this.scheduledTimeTimezone = const Value.absent(),
    this.notificationScheduled = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.deliveryStatus = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        reminderId = Value(reminderId),
        triggerType = Value(triggerType),
        scheduledTimeUtc = Value(scheduledTimeUtc);
  static Insertable<TriggerEntry> custom({
    Expression<String>? id,
    Expression<String>? reminderId,
    Expression<String>? triggerType,
    Expression<String>? scheduledTimeUtc,
    Expression<String>? scheduledTimeTimezone,
    Expression<int>? notificationScheduled,
    Expression<int>? notificationId,
    Expression<String>? firedAt,
    Expression<String>? deliveryStatus,
    Expression<String>? recurrenceRule,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reminderId != null) 'reminder_id': reminderId,
      if (triggerType != null) 'trigger_type': triggerType,
      if (scheduledTimeUtc != null) 'scheduled_time_utc': scheduledTimeUtc,
      if (scheduledTimeTimezone != null) 'scheduled_time_timezone': scheduledTimeTimezone,
      if (notificationScheduled != null) 'notification_scheduled': notificationScheduled,
      if (notificationId != null) 'notification_id': notificationId,
      if (firedAt != null) 'fired_at': firedAt,
      if (deliveryStatus != null) 'delivery_status': deliveryStatus,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TriggerTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? reminderId,
      Value<String>? triggerType,
      Value<String>? scheduledTimeUtc,
      Value<String>? scheduledTimeTimezone,
      Value<int>? notificationScheduled,
      Value<int?>? notificationId,
      Value<String?>? firedAt,
      Value<String>? deliveryStatus,
      Value<String?>? recurrenceRule,
      Value<int>? rowid}) {
    return TriggerTableCompanion(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      triggerType: triggerType ?? this.triggerType,
      scheduledTimeUtc: scheduledTimeUtc ?? this.scheduledTimeUtc,
      scheduledTimeTimezone: scheduledTimeTimezone ?? this.scheduledTimeTimezone,
      notificationScheduled: notificationScheduled ?? this.notificationScheduled,
      notificationId: notificationId ?? this.notificationId,
      firedAt: firedAt ?? this.firedAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (triggerType.present) {
      map['trigger_type'] = Variable<String>(triggerType.value);
    }
    if (scheduledTimeUtc.present) {
      map['scheduled_time_utc'] = Variable<String>(scheduledTimeUtc.value);
    }
    if (scheduledTimeTimezone.present) {
      map['scheduled_time_timezone'] = Variable<String>(scheduledTimeTimezone.value);
    }
    if (notificationScheduled.present) {
      map['notification_scheduled'] = Variable<int>(notificationScheduled.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<String>(firedAt.value);
    }
    if (deliveryStatus.present) {
      map['delivery_status'] = Variable<String>(deliveryStatus.value);
    }
    if (recurrenceRule.present) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TriggerTableCompanion(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('triggerType: $triggerType, ')
          ..write('scheduledTimeUtc: $scheduledTimeUtc, ')
          ..write('scheduledTimeTimezone: $scheduledTimeTimezone, ')
          ..write('notificationScheduled: $notificationScheduled, ')
          ..write('notificationId: $notificationId, ')
          ..write('firedAt: $firedAt, ')
          ..write('deliveryStatus: $deliveryStatus, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActionTableTable extends ActionTable with TableInfo<$ActionTableTable, ActionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActionTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id =
      GeneratedColumn<String>('id', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reminderIdMeta = const VerificationMeta('reminderId');
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>('reminder_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL UNIQUE REFERENCES reminder(id)');
  static const VerificationMeta _actionTypeMeta = const VerificationMeta('actionType');
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>('action_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL CHECK (action_type IN (\'CALL\', \'TEXT\', \'EMAIL\', \'OPEN_URL\', \'GENERAL\'))');
  static const VerificationMeta _targetValueMeta = const VerificationMeta('targetValue');
  @override
  late final GeneratedColumn<String> targetValue = GeneratedColumn<String>('target_value', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactNameMeta = const VerificationMeta('contactName');
  @override
  late final GeneratedColumn<String> contactName = GeneratedColumn<String>('contact_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactPhoneMeta = const VerificationMeta('contactPhone');
  @override
  late final GeneratedColumn<String> contactPhone = GeneratedColumn<String>('contact_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactIdMeta = const VerificationMeta('contactId');
  @override
  late final GeneratedColumn<String> contactId =
      GeneratedColumn<String>('contact_id', aliasedName, true, type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, reminderId, actionType, targetValue, contactName, contactPhone, contactId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'action_';
  @override
  VerificationContext validateIntegrity(Insertable<ActionEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('reminder_id')) {
      context.handle(_reminderIdMeta, reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta));
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(_actionTypeMeta, actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta));
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('target_value')) {
      context.handle(_targetValueMeta, targetValue.isAcceptableOrUnknown(data['target_value']!, _targetValueMeta));
    }
    if (data.containsKey('contact_name')) {
      context.handle(_contactNameMeta, contactName.isAcceptableOrUnknown(data['contact_name']!, _contactNameMeta));
    }
    if (data.containsKey('contact_phone')) {
      context.handle(_contactPhoneMeta, contactPhone.isAcceptableOrUnknown(data['contact_phone']!, _contactPhoneMeta));
    }
    if (data.containsKey('contact_id')) {
      context.handle(_contactIdMeta, contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActionEntry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      reminderId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}reminder_id'])!,
      actionType: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}action_type'])!,
      targetValue: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}target_value']),
      contactName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}contact_name']),
      contactPhone: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}contact_phone']),
      contactId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}contact_id']),
    );
  }

  @override
  $ActionTableTable createAlias(String alias) {
    return $ActionTableTable(attachedDatabase, alias);
  }
}

class ActionEntry extends DataClass implements Insertable<ActionEntry> {
  final String id;
  final String reminderId;
  final String actionType;
  final String? targetValue;
  final String? contactName;
  final String? contactPhone;
  final String? contactId;
  const ActionEntry(
      {required this.id,
      required this.reminderId,
      required this.actionType,
      this.targetValue,
      this.contactName,
      this.contactPhone,
      this.contactId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['reminder_id'] = Variable<String>(reminderId);
    map['action_type'] = Variable<String>(actionType);
    if (!nullToAbsent || targetValue != null) {
      map['target_value'] = Variable<String>(targetValue);
    }
    if (!nullToAbsent || contactName != null) {
      map['contact_name'] = Variable<String>(contactName);
    }
    if (!nullToAbsent || contactPhone != null) {
      map['contact_phone'] = Variable<String>(contactPhone);
    }
    if (!nullToAbsent || contactId != null) {
      map['contact_id'] = Variable<String>(contactId);
    }
    return map;
  }

  ActionTableCompanion toCompanion(bool nullToAbsent) {
    return ActionTableCompanion(
      id: Value(id),
      reminderId: Value(reminderId),
      actionType: Value(actionType),
      targetValue: targetValue == null && nullToAbsent ? const Value.absent() : Value(targetValue),
      contactName: contactName == null && nullToAbsent ? const Value.absent() : Value(contactName),
      contactPhone: contactPhone == null && nullToAbsent ? const Value.absent() : Value(contactPhone),
      contactId: contactId == null && nullToAbsent ? const Value.absent() : Value(contactId),
    );
  }

  factory ActionEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActionEntry(
      id: serializer.fromJson<String>(json['id']),
      reminderId: serializer.fromJson<String>(json['reminderId']),
      actionType: serializer.fromJson<String>(json['actionType']),
      targetValue: serializer.fromJson<String?>(json['targetValue']),
      contactName: serializer.fromJson<String?>(json['contactName']),
      contactPhone: serializer.fromJson<String?>(json['contactPhone']),
      contactId: serializer.fromJson<String?>(json['contactId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'reminderId': serializer.toJson<String>(reminderId),
      'actionType': serializer.toJson<String>(actionType),
      'targetValue': serializer.toJson<String?>(targetValue),
      'contactName': serializer.toJson<String?>(contactName),
      'contactPhone': serializer.toJson<String?>(contactPhone),
      'contactId': serializer.toJson<String?>(contactId),
    };
  }

  ActionEntry copyWith(
          {String? id,
          String? reminderId,
          String? actionType,
          Value<String?> targetValue = const Value.absent(),
          Value<String?> contactName = const Value.absent(),
          Value<String?> contactPhone = const Value.absent(),
          Value<String?> contactId = const Value.absent()}) =>
      ActionEntry(
        id: id ?? this.id,
        reminderId: reminderId ?? this.reminderId,
        actionType: actionType ?? this.actionType,
        targetValue: targetValue.present ? targetValue.value : this.targetValue,
        contactName: contactName.present ? contactName.value : this.contactName,
        contactPhone: contactPhone.present ? contactPhone.value : this.contactPhone,
        contactId: contactId.present ? contactId.value : this.contactId,
      );
  ActionEntry copyWithCompanion(ActionTableCompanion data) {
    return ActionEntry(
      id: data.id.present ? data.id.value : this.id,
      reminderId: data.reminderId.present ? data.reminderId.value : this.reminderId,
      actionType: data.actionType.present ? data.actionType.value : this.actionType,
      targetValue: data.targetValue.present ? data.targetValue.value : this.targetValue,
      contactName: data.contactName.present ? data.contactName.value : this.contactName,
      contactPhone: data.contactPhone.present ? data.contactPhone.value : this.contactPhone,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActionEntry(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('actionType: $actionType, ')
          ..write('targetValue: $targetValue, ')
          ..write('contactName: $contactName, ')
          ..write('contactPhone: $contactPhone, ')
          ..write('contactId: $contactId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, reminderId, actionType, targetValue, contactName, contactPhone, contactId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActionEntry &&
          other.id == this.id &&
          other.reminderId == this.reminderId &&
          other.actionType == this.actionType &&
          other.targetValue == this.targetValue &&
          other.contactName == this.contactName &&
          other.contactPhone == this.contactPhone &&
          other.contactId == this.contactId);
}

class ActionTableCompanion extends UpdateCompanion<ActionEntry> {
  final Value<String> id;
  final Value<String> reminderId;
  final Value<String> actionType;
  final Value<String?> targetValue;
  final Value<String?> contactName;
  final Value<String?> contactPhone;
  final Value<String?> contactId;
  final Value<int> rowid;
  const ActionTableCompanion({
    this.id = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.targetValue = const Value.absent(),
    this.contactName = const Value.absent(),
    this.contactPhone = const Value.absent(),
    this.contactId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActionTableCompanion.insert({
    required String id,
    required String reminderId,
    required String actionType,
    this.targetValue = const Value.absent(),
    this.contactName = const Value.absent(),
    this.contactPhone = const Value.absent(),
    this.contactId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        reminderId = Value(reminderId),
        actionType = Value(actionType);
  static Insertable<ActionEntry> custom({
    Expression<String>? id,
    Expression<String>? reminderId,
    Expression<String>? actionType,
    Expression<String>? targetValue,
    Expression<String>? contactName,
    Expression<String>? contactPhone,
    Expression<String>? contactId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reminderId != null) 'reminder_id': reminderId,
      if (actionType != null) 'action_type': actionType,
      if (targetValue != null) 'target_value': targetValue,
      if (contactName != null) 'contact_name': contactName,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (contactId != null) 'contact_id': contactId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActionTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? reminderId,
      Value<String>? actionType,
      Value<String?>? targetValue,
      Value<String?>? contactName,
      Value<String?>? contactPhone,
      Value<String?>? contactId,
      Value<int>? rowid}) {
    return ActionTableCompanion(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      actionType: actionType ?? this.actionType,
      targetValue: targetValue ?? this.targetValue,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactId: contactId ?? this.contactId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (targetValue.present) {
      map['target_value'] = Variable<String>(targetValue.value);
    }
    if (contactName.present) {
      map['contact_name'] = Variable<String>(contactName.value);
    }
    if (contactPhone.present) {
      map['contact_phone'] = Variable<String>(contactPhone.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActionTableCompanion(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('actionType: $actionType, ')
          ..write('targetValue: $targetValue, ')
          ..write('contactName: $contactName, ')
          ..write('contactPhone: $contactPhone, ')
          ..write('contactId: $contactId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataTableTable extends AppMetadataTable with TableInfo<$AppMetadataTableTable, AppMetadataEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key =
      GeneratedColumn<String>('key', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value =
      GeneratedColumn<String>('value', aliasedName, false, type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<AppMetadataEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataEntry(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppMetadataTableTable createAlias(String alias) {
    return $AppMetadataTableTable(attachedDatabase, alias);
  }
}

class AppMetadataEntry extends DataClass implements Insertable<AppMetadataEntry> {
  final String key;
  final String value;
  const AppMetadataEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetadataTableCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataTableCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppMetadataEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetadataEntry copyWith({String? key, String? value}) => AppMetadataEntry(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppMetadataEntry copyWithCompanion(AppMetadataTableCompanion data) {
    return AppMetadataEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppMetadataEntry && other.key == this.key && other.value == this.value);
}

class AppMetadataTableCompanion extends UpdateCompanion<AppMetadataEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetadataTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataTableCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppMetadataEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataTableCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppMetadataTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ReminderTableTable reminderTable = $ReminderTableTable(this);
  late final $TriggerTableTable triggerTable = $TriggerTableTable(this);
  late final $ActionTableTable actionTable = $ActionTableTable(this);
  late final $AppMetadataTableTable appMetadataTable = $AppMetadataTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [reminderTable, triggerTable, actionTable, appMetadataTable];
}

typedef $$ReminderTableTableCreateCompanionBuilder = ReminderTableCompanion Function({
  required String id,
  required String title,
  Value<String?> notes,
  required String intentType,
  Value<String> status,
  Value<int> snoozeCount,
  Value<int> snoozeDurationMinutes,
  Value<String?> parentReminderId,
  Value<int> depth,
  Value<int> version,
  Value<String?> originalTranscript,
  required String createdAt,
  required String updatedAt,
  Value<String?> completedAt,
  Value<int> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});
typedef $$ReminderTableTableUpdateCompanionBuilder = ReminderTableCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> notes,
  Value<String> intentType,
  Value<String> status,
  Value<int> snoozeCount,
  Value<int> snoozeDurationMinutes,
  Value<String?> parentReminderId,
  Value<int> depth,
  Value<int> version,
  Value<String?> originalTranscript,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String?> completedAt,
  Value<int> isDeleted,
  Value<String?> deletedAt,
  Value<int> rowid,
});

class $$ReminderTableTableFilterComposer extends Composer<_$AppDatabase, $ReminderTableTable> {
  $$ReminderTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get intentType =>
      $composableBuilder(column: $table.intentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get snoozeCount =>
      $composableBuilder(column: $table.snoozeCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get snoozeDurationMinutes =>
      $composableBuilder(column: $table.snoozeDurationMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentReminderId =>
      $composableBuilder(column: $table.parentReminderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get depth => $composableBuilder(column: $table.depth, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalTranscript =>
      $composableBuilder(column: $table.originalTranscript, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get completedAt =>
      $composableBuilder(column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$ReminderTableTableOrderingComposer extends Composer<_$AppDatabase, $ReminderTableTable> {
  $$ReminderTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get intentType =>
      $composableBuilder(column: $table.intentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get snoozeCount =>
      $composableBuilder(column: $table.snoozeCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get snoozeDurationMinutes =>
      $composableBuilder(column: $table.snoozeDurationMinutes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentReminderId =>
      $composableBuilder(column: $table.parentReminderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get depth =>
      $composableBuilder(column: $table.depth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalTranscript =>
      $composableBuilder(column: $table.originalTranscript, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get completedAt =>
      $composableBuilder(column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$ReminderTableTableAnnotationComposer extends Composer<_$AppDatabase, $ReminderTableTable> {
  $$ReminderTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get intentType => $composableBuilder(column: $table.intentType, builder: (column) => column);

  GeneratedColumn<String> get status => $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get snoozeCount => $composableBuilder(column: $table.snoozeCount, builder: (column) => column);

  GeneratedColumn<int> get snoozeDurationMinutes =>
      $composableBuilder(column: $table.snoozeDurationMinutes, builder: (column) => column);

  GeneratedColumn<String> get parentReminderId =>
      $composableBuilder(column: $table.parentReminderId, builder: (column) => column);

  GeneratedColumn<int> get depth => $composableBuilder(column: $table.depth, builder: (column) => column);

  GeneratedColumn<int> get version => $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get originalTranscript =>
      $composableBuilder(column: $table.originalTranscript, builder: (column) => column);

  GeneratedColumn<String> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt =>
      $composableBuilder(column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get isDeleted => $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get deletedAt => $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ReminderTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReminderTableTable,
    ReminderEntry,
    $$ReminderTableTableFilterComposer,
    $$ReminderTableTableOrderingComposer,
    $$ReminderTableTableAnnotationComposer,
    $$ReminderTableTableCreateCompanionBuilder,
    $$ReminderTableTableUpdateCompanionBuilder,
    (ReminderEntry, BaseReferences<_$AppDatabase, $ReminderTableTable, ReminderEntry>),
    ReminderEntry,
    PrefetchHooks Function()> {
  $$ReminderTableTableTableManager(_$AppDatabase db, $ReminderTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ReminderTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ReminderTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ReminderTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> intentType = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> snoozeCount = const Value.absent(),
            Value<int> snoozeDurationMinutes = const Value.absent(),
            Value<String?> parentReminderId = const Value.absent(),
            Value<int> depth = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> originalTranscript = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<String?> completedAt = const Value.absent(),
            Value<int> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReminderTableCompanion(
            id: id,
            title: title,
            notes: notes,
            intentType: intentType,
            status: status,
            snoozeCount: snoozeCount,
            snoozeDurationMinutes: snoozeDurationMinutes,
            parentReminderId: parentReminderId,
            depth: depth,
            version: version,
            originalTranscript: originalTranscript,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String?> notes = const Value.absent(),
            required String intentType,
            Value<String> status = const Value.absent(),
            Value<int> snoozeCount = const Value.absent(),
            Value<int> snoozeDurationMinutes = const Value.absent(),
            Value<String?> parentReminderId = const Value.absent(),
            Value<int> depth = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> originalTranscript = const Value.absent(),
            required String createdAt,
            required String updatedAt,
            Value<String?> completedAt = const Value.absent(),
            Value<int> isDeleted = const Value.absent(),
            Value<String?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReminderTableCompanion.insert(
            id: id,
            title: title,
            notes: notes,
            intentType: intentType,
            status: status,
            snoozeCount: snoozeCount,
            snoozeDurationMinutes: snoozeDurationMinutes,
            parentReminderId: parentReminderId,
            depth: depth,
            version: version,
            originalTranscript: originalTranscript,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            isDeleted: isDeleted,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReminderTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReminderTableTable,
    ReminderEntry,
    $$ReminderTableTableFilterComposer,
    $$ReminderTableTableOrderingComposer,
    $$ReminderTableTableAnnotationComposer,
    $$ReminderTableTableCreateCompanionBuilder,
    $$ReminderTableTableUpdateCompanionBuilder,
    (ReminderEntry, BaseReferences<_$AppDatabase, $ReminderTableTable, ReminderEntry>),
    ReminderEntry,
    PrefetchHooks Function()>;
typedef $$TriggerTableTableCreateCompanionBuilder = TriggerTableCompanion Function({
  required String id,
  required String reminderId,
  required String triggerType,
  required String scheduledTimeUtc,
  Value<String> scheduledTimeTimezone,
  Value<int> notificationScheduled,
  Value<int?> notificationId,
  Value<String?> firedAt,
  Value<String> deliveryStatus,
  Value<String?> recurrenceRule,
  Value<int> rowid,
});
typedef $$TriggerTableTableUpdateCompanionBuilder = TriggerTableCompanion Function({
  Value<String> id,
  Value<String> reminderId,
  Value<String> triggerType,
  Value<String> scheduledTimeUtc,
  Value<String> scheduledTimeTimezone,
  Value<int> notificationScheduled,
  Value<int?> notificationId,
  Value<String?> firedAt,
  Value<String> deliveryStatus,
  Value<String?> recurrenceRule,
  Value<int> rowid,
});

class $$TriggerTableTableFilterComposer extends Composer<_$AppDatabase, $TriggerTableTable> {
  $$TriggerTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderId =>
      $composableBuilder(column: $table.reminderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get triggerType =>
      $composableBuilder(column: $table.triggerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scheduledTimeUtc =>
      $composableBuilder(column: $table.scheduledTimeUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scheduledTimeTimezone =>
      $composableBuilder(column: $table.scheduledTimeTimezone, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get notificationScheduled =>
      $composableBuilder(column: $table.notificationScheduled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get notificationId =>
      $composableBuilder(column: $table.notificationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deliveryStatus =>
      $composableBuilder(column: $table.deliveryStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recurrenceRule =>
      $composableBuilder(column: $table.recurrenceRule, builder: (column) => ColumnFilters(column));
}

class $$TriggerTableTableOrderingComposer extends Composer<_$AppDatabase, $TriggerTableTable> {
  $$TriggerTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderId =>
      $composableBuilder(column: $table.reminderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get triggerType =>
      $composableBuilder(column: $table.triggerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scheduledTimeUtc =>
      $composableBuilder(column: $table.scheduledTimeUtc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scheduledTimeTimezone =>
      $composableBuilder(column: $table.scheduledTimeTimezone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get notificationScheduled =>
      $composableBuilder(column: $table.notificationScheduled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get notificationId =>
      $composableBuilder(column: $table.notificationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deliveryStatus =>
      $composableBuilder(column: $table.deliveryStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recurrenceRule =>
      $composableBuilder(column: $table.recurrenceRule, builder: (column) => ColumnOrderings(column));
}

class $$TriggerTableTableAnnotationComposer extends Composer<_$AppDatabase, $TriggerTableTable> {
  $$TriggerTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get reminderId => $composableBuilder(column: $table.reminderId, builder: (column) => column);

  GeneratedColumn<String> get triggerType =>
      $composableBuilder(column: $table.triggerType, builder: (column) => column);

  GeneratedColumn<String> get scheduledTimeUtc =>
      $composableBuilder(column: $table.scheduledTimeUtc, builder: (column) => column);

  GeneratedColumn<String> get scheduledTimeTimezone =>
      $composableBuilder(column: $table.scheduledTimeTimezone, builder: (column) => column);

  GeneratedColumn<int> get notificationScheduled =>
      $composableBuilder(column: $table.notificationScheduled, builder: (column) => column);

  GeneratedColumn<int> get notificationId =>
      $composableBuilder(column: $table.notificationId, builder: (column) => column);

  GeneratedColumn<String> get firedAt => $composableBuilder(column: $table.firedAt, builder: (column) => column);

  GeneratedColumn<String> get deliveryStatus =>
      $composableBuilder(column: $table.deliveryStatus, builder: (column) => column);

  GeneratedColumn<String> get recurrenceRule =>
      $composableBuilder(column: $table.recurrenceRule, builder: (column) => column);
}

class $$TriggerTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TriggerTableTable,
    TriggerEntry,
    $$TriggerTableTableFilterComposer,
    $$TriggerTableTableOrderingComposer,
    $$TriggerTableTableAnnotationComposer,
    $$TriggerTableTableCreateCompanionBuilder,
    $$TriggerTableTableUpdateCompanionBuilder,
    (TriggerEntry, BaseReferences<_$AppDatabase, $TriggerTableTable, TriggerEntry>),
    TriggerEntry,
    PrefetchHooks Function()> {
  $$TriggerTableTableTableManager(_$AppDatabase db, $TriggerTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TriggerTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TriggerTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TriggerTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> reminderId = const Value.absent(),
            Value<String> triggerType = const Value.absent(),
            Value<String> scheduledTimeUtc = const Value.absent(),
            Value<String> scheduledTimeTimezone = const Value.absent(),
            Value<int> notificationScheduled = const Value.absent(),
            Value<int?> notificationId = const Value.absent(),
            Value<String?> firedAt = const Value.absent(),
            Value<String> deliveryStatus = const Value.absent(),
            Value<String?> recurrenceRule = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TriggerTableCompanion(
            id: id,
            reminderId: reminderId,
            triggerType: triggerType,
            scheduledTimeUtc: scheduledTimeUtc,
            scheduledTimeTimezone: scheduledTimeTimezone,
            notificationScheduled: notificationScheduled,
            notificationId: notificationId,
            firedAt: firedAt,
            deliveryStatus: deliveryStatus,
            recurrenceRule: recurrenceRule,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String reminderId,
            required String triggerType,
            required String scheduledTimeUtc,
            Value<String> scheduledTimeTimezone = const Value.absent(),
            Value<int> notificationScheduled = const Value.absent(),
            Value<int?> notificationId = const Value.absent(),
            Value<String?> firedAt = const Value.absent(),
            Value<String> deliveryStatus = const Value.absent(),
            Value<String?> recurrenceRule = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TriggerTableCompanion.insert(
            id: id,
            reminderId: reminderId,
            triggerType: triggerType,
            scheduledTimeUtc: scheduledTimeUtc,
            scheduledTimeTimezone: scheduledTimeTimezone,
            notificationScheduled: notificationScheduled,
            notificationId: notificationId,
            firedAt: firedAt,
            deliveryStatus: deliveryStatus,
            recurrenceRule: recurrenceRule,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TriggerTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TriggerTableTable,
    TriggerEntry,
    $$TriggerTableTableFilterComposer,
    $$TriggerTableTableOrderingComposer,
    $$TriggerTableTableAnnotationComposer,
    $$TriggerTableTableCreateCompanionBuilder,
    $$TriggerTableTableUpdateCompanionBuilder,
    (TriggerEntry, BaseReferences<_$AppDatabase, $TriggerTableTable, TriggerEntry>),
    TriggerEntry,
    PrefetchHooks Function()>;
typedef $$ActionTableTableCreateCompanionBuilder = ActionTableCompanion Function({
  required String id,
  required String reminderId,
  required String actionType,
  Value<String?> targetValue,
  Value<String?> contactName,
  Value<String?> contactPhone,
  Value<String?> contactId,
  Value<int> rowid,
});
typedef $$ActionTableTableUpdateCompanionBuilder = ActionTableCompanion Function({
  Value<String> id,
  Value<String> reminderId,
  Value<String> actionType,
  Value<String?> targetValue,
  Value<String?> contactName,
  Value<String?> contactPhone,
  Value<String?> contactId,
  Value<int> rowid,
});

class $$ActionTableTableFilterComposer extends Composer<_$AppDatabase, $ActionTableTable> {
  $$ActionTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reminderId =>
      $composableBuilder(column: $table.reminderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actionType =>
      $composableBuilder(column: $table.actionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetValue =>
      $composableBuilder(column: $table.targetValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactName =>
      $composableBuilder(column: $table.contactName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactPhone =>
      $composableBuilder(column: $table.contactPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => ColumnFilters(column));
}

class $$ActionTableTableOrderingComposer extends Composer<_$AppDatabase, $ActionTableTable> {
  $$ActionTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reminderId =>
      $composableBuilder(column: $table.reminderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actionType =>
      $composableBuilder(column: $table.actionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetValue =>
      $composableBuilder(column: $table.targetValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactName =>
      $composableBuilder(column: $table.contactName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactPhone =>
      $composableBuilder(column: $table.contactPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => ColumnOrderings(column));
}

class $$ActionTableTableAnnotationComposer extends Composer<_$AppDatabase, $ActionTableTable> {
  $$ActionTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get reminderId => $composableBuilder(column: $table.reminderId, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(column: $table.actionType, builder: (column) => column);

  GeneratedColumn<String> get targetValue =>
      $composableBuilder(column: $table.targetValue, builder: (column) => column);

  GeneratedColumn<String> get contactName =>
      $composableBuilder(column: $table.contactName, builder: (column) => column);

  GeneratedColumn<String> get contactPhone =>
      $composableBuilder(column: $table.contactPhone, builder: (column) => column);

  GeneratedColumn<String> get contactId => $composableBuilder(column: $table.contactId, builder: (column) => column);
}

class $$ActionTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ActionTableTable,
    ActionEntry,
    $$ActionTableTableFilterComposer,
    $$ActionTableTableOrderingComposer,
    $$ActionTableTableAnnotationComposer,
    $$ActionTableTableCreateCompanionBuilder,
    $$ActionTableTableUpdateCompanionBuilder,
    (ActionEntry, BaseReferences<_$AppDatabase, $ActionTableTable, ActionEntry>),
    ActionEntry,
    PrefetchHooks Function()> {
  $$ActionTableTableTableManager(_$AppDatabase db, $ActionTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ActionTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ActionTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ActionTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> reminderId = const Value.absent(),
            Value<String> actionType = const Value.absent(),
            Value<String?> targetValue = const Value.absent(),
            Value<String?> contactName = const Value.absent(),
            Value<String?> contactPhone = const Value.absent(),
            Value<String?> contactId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ActionTableCompanion(
            id: id,
            reminderId: reminderId,
            actionType: actionType,
            targetValue: targetValue,
            contactName: contactName,
            contactPhone: contactPhone,
            contactId: contactId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String reminderId,
            required String actionType,
            Value<String?> targetValue = const Value.absent(),
            Value<String?> contactName = const Value.absent(),
            Value<String?> contactPhone = const Value.absent(),
            Value<String?> contactId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ActionTableCompanion.insert(
            id: id,
            reminderId: reminderId,
            actionType: actionType,
            targetValue: targetValue,
            contactName: contactName,
            contactPhone: contactPhone,
            contactId: contactId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ActionTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ActionTableTable,
    ActionEntry,
    $$ActionTableTableFilterComposer,
    $$ActionTableTableOrderingComposer,
    $$ActionTableTableAnnotationComposer,
    $$ActionTableTableCreateCompanionBuilder,
    $$ActionTableTableUpdateCompanionBuilder,
    (ActionEntry, BaseReferences<_$AppDatabase, $ActionTableTable, ActionEntry>),
    ActionEntry,
    PrefetchHooks Function()>;
typedef $$AppMetadataTableTableCreateCompanionBuilder = AppMetadataTableCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetadataTableTableUpdateCompanionBuilder = AppMetadataTableCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetadataTableTableFilterComposer extends Composer<_$AppDatabase, $AppMetadataTableTable> {
  $$AppMetadataTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppMetadataTableTableOrderingComposer extends Composer<_$AppDatabase, $AppMetadataTableTable> {
  $$AppMetadataTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppMetadataTableTableAnnotationComposer extends Composer<_$AppDatabase, $AppMetadataTableTable> {
  $$AppMetadataTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetadataTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppMetadataTableTable,
    AppMetadataEntry,
    $$AppMetadataTableTableFilterComposer,
    $$AppMetadataTableTableOrderingComposer,
    $$AppMetadataTableTableAnnotationComposer,
    $$AppMetadataTableTableCreateCompanionBuilder,
    $$AppMetadataTableTableUpdateCompanionBuilder,
    (AppMetadataEntry, BaseReferences<_$AppDatabase, $AppMetadataTableTable, AppMetadataEntry>),
    AppMetadataEntry,
    PrefetchHooks Function()> {
  $$AppMetadataTableTableTableManager(_$AppDatabase db, $AppMetadataTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AppMetadataTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AppMetadataTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AppMetadataTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetadataTableCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetadataTableCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppMetadataTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppMetadataTableTable,
    AppMetadataEntry,
    $$AppMetadataTableTableFilterComposer,
    $$AppMetadataTableTableOrderingComposer,
    $$AppMetadataTableTableAnnotationComposer,
    $$AppMetadataTableTableCreateCompanionBuilder,
    $$AppMetadataTableTableUpdateCompanionBuilder,
    (AppMetadataEntry, BaseReferences<_$AppDatabase, $AppMetadataTableTable, AppMetadataEntry>),
    AppMetadataEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ReminderTableTableTableManager get reminderTable => $$ReminderTableTableTableManager(_db, _db.reminderTable);
  $$TriggerTableTableTableManager get triggerTable => $$TriggerTableTableTableManager(_db, _db.triggerTable);
  $$ActionTableTableTableManager get actionTable => $$ActionTableTableTableManager(_db, _db.actionTable);
  $$AppMetadataTableTableTableManager get appMetadataTable =>
      $$AppMetadataTableTableTableManager(_db, _db.appMetadataTable);
}
