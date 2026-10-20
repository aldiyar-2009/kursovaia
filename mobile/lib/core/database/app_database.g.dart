// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SubjectsTable extends Subjects with TableInfo<$SubjectsTable, Subject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teacherNameMeta = const VerificationMeta(
    'teacherName',
  );
  @override
  late final GeneratedColumn<String> teacherName = GeneratedColumn<String>(
    'teacher_name',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 160),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 9),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAt = GeneratedColumn<BigInt>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    title,
    teacherName,
    colorHex,
    isDeleted,
    updatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('teacher_name')) {
      context.handle(
        _teacherNameMeta,
        teacherName.isAcceptableOrUnknown(
          data['teacher_name']!,
          _teacherNameMeta,
        ),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      teacherName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teacher_name'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $SubjectsTable createAlias(String alias) {
    return $SubjectsTable(attachedDatabase, alias);
  }
}

class Subject extends DataClass implements Insertable<Subject> {
  final String id;
  final String userId;
  final String title;
  final String? teacherName;
  final String? colorHex;
  final bool isDeleted;
  final BigInt updatedAt;
  final String syncStatus;
  const Subject({
    required this.id,
    required this.userId,
    required this.title,
    this.teacherName,
    this.colorHex,
    required this.isDeleted,
    required this.updatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || teacherName != null) {
      map['teacher_name'] = Variable<String>(teacherName);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['updated_at'] = Variable<BigInt>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      id: Value(id),
      userId: Value(userId),
      title: Value(title),
      teacherName: teacherName == null && nullToAbsent
          ? const Value.absent()
          : Value(teacherName),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      isDeleted: Value(isDeleted),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Subject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subject(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      title: serializer.fromJson<String>(json['title']),
      teacherName: serializer.fromJson<String?>(json['teacherName']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<BigInt>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'title': serializer.toJson<String>(title),
      'teacherName': serializer.toJson<String?>(teacherName),
      'colorHex': serializer.toJson<String?>(colorHex),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<BigInt>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Subject copyWith({
    String? id,
    String? userId,
    String? title,
    Value<String?> teacherName = const Value.absent(),
    Value<String?> colorHex = const Value.absent(),
    bool? isDeleted,
    BigInt? updatedAt,
    String? syncStatus,
  }) => Subject(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    teacherName: teacherName.present ? teacherName.value : this.teacherName,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Subject copyWithCompanion(SubjectsCompanion data) {
    return Subject(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      title: data.title.present ? data.title.value : this.title,
      teacherName: data.teacherName.present
          ? data.teacherName.value
          : this.teacherName,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subject(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('teacherName: $teacherName, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    teacherName,
    colorHex,
    isDeleted,
    updatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subject &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.title == this.title &&
          other.teacherName == this.teacherName &&
          other.colorHex == this.colorHex &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus);
}

class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> title;
  final Value<String?> teacherName;
  final Value<String?> colorHex;
  final Value<bool> isDeleted;
  final Value<BigInt> updatedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    this.teacherName = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectsCompanion.insert({
    required String id,
    required String userId,
    required String title,
    this.teacherName = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required BigInt updatedAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<Subject> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? title,
    Expression<String>? teacherName,
    Expression<String>? colorHex,
    Expression<bool>? isDeleted,
    Expression<BigInt>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (title != null) 'title': title,
      if (teacherName != null) 'teacher_name': teacherName,
      if (colorHex != null) 'color_hex': colorHex,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? title,
    Value<String?>? teacherName,
    Value<String?>? colorHex,
    Value<bool>? isDeleted,
    Value<BigInt>? updatedAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      teacherName: teacherName ?? this.teacherName,
      colorHex: colorHex ?? this.colorHex,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (teacherName.present) {
      map['teacher_name'] = Variable<String>(teacherName.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<BigInt>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('teacherName: $teacherName, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LessonsTable extends Lessons with TableInfo<$LessonsTable, Lesson> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
    'day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 5,
      maxTextLength: 5,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 5,
      maxTextLength: 5,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _classroomMeta = const VerificationMeta(
    'classroom',
  );
  @override
  late final GeneratedColumn<String> classroom = GeneratedColumn<String>(
    'classroom',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 64),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lessonTypeMeta = const VerificationMeta(
    'lessonType',
  );
  @override
  late final GeneratedColumn<String> lessonType = GeneratedColumn<String>(
    'lesson_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('lecture'),
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 255),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEvenWeekMeta = const VerificationMeta(
    'isEvenWeek',
  );
  @override
  late final GeneratedColumn<bool> isEvenWeek = GeneratedColumn<bool>(
    'is_even_week',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_even_week" IN (0, 1))',
    ),
  );
  static const VerificationMeta _specificDateMeta = const VerificationMeta(
    'specificDate',
  );
  @override
  late final GeneratedColumn<String> specificDate = GeneratedColumn<String>(
    'specific_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validFromMeta = const VerificationMeta(
    'validFrom',
  );
  @override
  late final GeneratedColumn<String> validFrom = GeneratedColumn<String>(
    'valid_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validToMeta = const VerificationMeta(
    'validTo',
  );
  @override
  late final GeneratedColumn<String> validTo = GeneratedColumn<String>(
    'valid_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCancelledMeta = const VerificationMeta(
    'isCancelled',
  );
  @override
  late final GeneratedColumn<bool> isCancelled = GeneratedColumn<bool>(
    'is_cancelled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cancelled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAt = GeneratedColumn<BigInt>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    userId,
    dayOfWeek,
    startTime,
    endTime,
    classroom,
    lessonType,
    topic,
    isEvenWeek,
    specificDate,
    validFrom,
    validTo,
    isCancelled,
    isDeleted,
    updatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lesson> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('classroom')) {
      context.handle(
        _classroomMeta,
        classroom.isAcceptableOrUnknown(data['classroom']!, _classroomMeta),
      );
    }
    if (data.containsKey('lesson_type')) {
      context.handle(
        _lessonTypeMeta,
        lessonType.isAcceptableOrUnknown(data['lesson_type']!, _lessonTypeMeta),
      );
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    }
    if (data.containsKey('is_even_week')) {
      context.handle(
        _isEvenWeekMeta,
        isEvenWeek.isAcceptableOrUnknown(
          data['is_even_week']!,
          _isEvenWeekMeta,
        ),
      );
    }
    if (data.containsKey('specific_date')) {
      context.handle(
        _specificDateMeta,
        specificDate.isAcceptableOrUnknown(
          data['specific_date']!,
          _specificDateMeta,
        ),
      );
    }
    if (data.containsKey('valid_from')) {
      context.handle(
        _validFromMeta,
        validFrom.isAcceptableOrUnknown(data['valid_from']!, _validFromMeta),
      );
    }
    if (data.containsKey('valid_to')) {
      context.handle(
        _validToMeta,
        validTo.isAcceptableOrUnknown(data['valid_to']!, _validToMeta),
      );
    }
    if (data.containsKey('is_cancelled')) {
      context.handle(
        _isCancelledMeta,
        isCancelled.isAcceptableOrUnknown(
          data['is_cancelled']!,
          _isCancelledMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lesson map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lesson(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_week'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      )!,
      classroom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classroom'],
      ),
      lessonType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_type'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      ),
      isEvenWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_even_week'],
      ),
      specificDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}specific_date'],
      ),
      validFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_from'],
      ),
      validTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_to'],
      ),
      isCancelled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cancelled'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LessonsTable createAlias(String alias) {
    return $LessonsTable(attachedDatabase, alias);
  }
}

class Lesson extends DataClass implements Insertable<Lesson> {
  final String id;
  final String subjectId;
  final String userId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? classroom;
  final String lessonType;
  final String? topic;
  final bool? isEvenWeek;
  final String? specificDate;
  final String? validFrom;
  final String? validTo;
  final bool isCancelled;
  final bool isDeleted;
  final BigInt updatedAt;
  final String syncStatus;
  const Lesson({
    required this.id,
    required this.subjectId,
    required this.userId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.classroom,
    required this.lessonType,
    this.topic,
    this.isEvenWeek,
    this.specificDate,
    this.validFrom,
    this.validTo,
    required this.isCancelled,
    required this.isDeleted,
    required this.updatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_id'] = Variable<String>(subjectId);
    map['user_id'] = Variable<String>(userId);
    map['day_of_week'] = Variable<int>(dayOfWeek);
    map['start_time'] = Variable<String>(startTime);
    map['end_time'] = Variable<String>(endTime);
    if (!nullToAbsent || classroom != null) {
      map['classroom'] = Variable<String>(classroom);
    }
    map['lesson_type'] = Variable<String>(lessonType);
    if (!nullToAbsent || topic != null) {
      map['topic'] = Variable<String>(topic);
    }
    if (!nullToAbsent || isEvenWeek != null) {
      map['is_even_week'] = Variable<bool>(isEvenWeek);
    }
    if (!nullToAbsent || specificDate != null) {
      map['specific_date'] = Variable<String>(specificDate);
    }
    if (!nullToAbsent || validFrom != null) {
      map['valid_from'] = Variable<String>(validFrom);
    }
    if (!nullToAbsent || validTo != null) {
      map['valid_to'] = Variable<String>(validTo);
    }
    map['is_cancelled'] = Variable<bool>(isCancelled);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['updated_at'] = Variable<BigInt>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LessonsCompanion toCompanion(bool nullToAbsent) {
    return LessonsCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      userId: Value(userId),
      dayOfWeek: Value(dayOfWeek),
      startTime: Value(startTime),
      endTime: Value(endTime),
      classroom: classroom == null && nullToAbsent
          ? const Value.absent()
          : Value(classroom),
      lessonType: Value(lessonType),
      topic: topic == null && nullToAbsent
          ? const Value.absent()
          : Value(topic),
      isEvenWeek: isEvenWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(isEvenWeek),
      specificDate: specificDate == null && nullToAbsent
          ? const Value.absent()
          : Value(specificDate),
      validFrom: validFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(validFrom),
      validTo: validTo == null && nullToAbsent
          ? const Value.absent()
          : Value(validTo),
      isCancelled: Value(isCancelled),
      isDeleted: Value(isDeleted),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Lesson.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lesson(
      id: serializer.fromJson<String>(json['id']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      userId: serializer.fromJson<String>(json['userId']),
      dayOfWeek: serializer.fromJson<int>(json['dayOfWeek']),
      startTime: serializer.fromJson<String>(json['startTime']),
      endTime: serializer.fromJson<String>(json['endTime']),
      classroom: serializer.fromJson<String?>(json['classroom']),
      lessonType: serializer.fromJson<String>(json['lessonType']),
      topic: serializer.fromJson<String?>(json['topic']),
      isEvenWeek: serializer.fromJson<bool?>(json['isEvenWeek']),
      specificDate: serializer.fromJson<String?>(json['specificDate']),
      validFrom: serializer.fromJson<String?>(json['validFrom']),
      validTo: serializer.fromJson<String?>(json['validTo']),
      isCancelled: serializer.fromJson<bool>(json['isCancelled']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<BigInt>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectId': serializer.toJson<String>(subjectId),
      'userId': serializer.toJson<String>(userId),
      'dayOfWeek': serializer.toJson<int>(dayOfWeek),
      'startTime': serializer.toJson<String>(startTime),
      'endTime': serializer.toJson<String>(endTime),
      'classroom': serializer.toJson<String?>(classroom),
      'lessonType': serializer.toJson<String>(lessonType),
      'topic': serializer.toJson<String?>(topic),
      'isEvenWeek': serializer.toJson<bool?>(isEvenWeek),
      'specificDate': serializer.toJson<String?>(specificDate),
      'validFrom': serializer.toJson<String?>(validFrom),
      'validTo': serializer.toJson<String?>(validTo),
      'isCancelled': serializer.toJson<bool>(isCancelled),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<BigInt>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Lesson copyWith({
    String? id,
    String? subjectId,
    String? userId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    Value<String?> classroom = const Value.absent(),
    String? lessonType,
    Value<String?> topic = const Value.absent(),
    Value<bool?> isEvenWeek = const Value.absent(),
    Value<String?> specificDate = const Value.absent(),
    Value<String?> validFrom = const Value.absent(),
    Value<String?> validTo = const Value.absent(),
    bool? isCancelled,
    bool? isDeleted,
    BigInt? updatedAt,
    String? syncStatus,
  }) => Lesson(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    userId: userId ?? this.userId,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    classroom: classroom.present ? classroom.value : this.classroom,
    lessonType: lessonType ?? this.lessonType,
    topic: topic.present ? topic.value : this.topic,
    isEvenWeek: isEvenWeek.present ? isEvenWeek.value : this.isEvenWeek,
    specificDate: specificDate.present ? specificDate.value : this.specificDate,
    validFrom: validFrom.present ? validFrom.value : this.validFrom,
    validTo: validTo.present ? validTo.value : this.validTo,
    isCancelled: isCancelled ?? this.isCancelled,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Lesson copyWithCompanion(LessonsCompanion data) {
    return Lesson(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      userId: data.userId.present ? data.userId.value : this.userId,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      classroom: data.classroom.present ? data.classroom.value : this.classroom,
      lessonType: data.lessonType.present
          ? data.lessonType.value
          : this.lessonType,
      topic: data.topic.present ? data.topic.value : this.topic,
      isEvenWeek: data.isEvenWeek.present
          ? data.isEvenWeek.value
          : this.isEvenWeek,
      specificDate: data.specificDate.present
          ? data.specificDate.value
          : this.specificDate,
      validFrom: data.validFrom.present ? data.validFrom.value : this.validFrom,
      validTo: data.validTo.present ? data.validTo.value : this.validTo,
      isCancelled: data.isCancelled.present
          ? data.isCancelled.value
          : this.isCancelled,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lesson(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('userId: $userId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('classroom: $classroom, ')
          ..write('lessonType: $lessonType, ')
          ..write('topic: $topic, ')
          ..write('isEvenWeek: $isEvenWeek, ')
          ..write('specificDate: $specificDate, ')
          ..write('validFrom: $validFrom, ')
          ..write('validTo: $validTo, ')
          ..write('isCancelled: $isCancelled, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectId,
    userId,
    dayOfWeek,
    startTime,
    endTime,
    classroom,
    lessonType,
    topic,
    isEvenWeek,
    specificDate,
    validFrom,
    validTo,
    isCancelled,
    isDeleted,
    updatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lesson &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.userId == this.userId &&
          other.dayOfWeek == this.dayOfWeek &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.classroom == this.classroom &&
          other.lessonType == this.lessonType &&
          other.topic == this.topic &&
          other.isEvenWeek == this.isEvenWeek &&
          other.specificDate == this.specificDate &&
          other.validFrom == this.validFrom &&
          other.validTo == this.validTo &&
          other.isCancelled == this.isCancelled &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus);
}

class LessonsCompanion extends UpdateCompanion<Lesson> {
  final Value<String> id;
  final Value<String> subjectId;
  final Value<String> userId;
  final Value<int> dayOfWeek;
  final Value<String> startTime;
  final Value<String> endTime;
  final Value<String?> classroom;
  final Value<String> lessonType;
  final Value<String?> topic;
  final Value<bool?> isEvenWeek;
  final Value<String?> specificDate;
  final Value<String?> validFrom;
  final Value<String?> validTo;
  final Value<bool> isCancelled;
  final Value<bool> isDeleted;
  final Value<BigInt> updatedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LessonsCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.userId = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.classroom = const Value.absent(),
    this.lessonType = const Value.absent(),
    this.topic = const Value.absent(),
    this.isEvenWeek = const Value.absent(),
    this.specificDate = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validTo = const Value.absent(),
    this.isCancelled = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonsCompanion.insert({
    required String id,
    required String subjectId,
    required String userId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    this.classroom = const Value.absent(),
    this.lessonType = const Value.absent(),
    this.topic = const Value.absent(),
    this.isEvenWeek = const Value.absent(),
    this.specificDate = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validTo = const Value.absent(),
    this.isCancelled = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required BigInt updatedAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectId = Value(subjectId),
       userId = Value(userId),
       dayOfWeek = Value(dayOfWeek),
       startTime = Value(startTime),
       endTime = Value(endTime),
       updatedAt = Value(updatedAt);
  static Insertable<Lesson> custom({
    Expression<String>? id,
    Expression<String>? subjectId,
    Expression<String>? userId,
    Expression<int>? dayOfWeek,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<String>? classroom,
    Expression<String>? lessonType,
    Expression<String>? topic,
    Expression<bool>? isEvenWeek,
    Expression<String>? specificDate,
    Expression<String>? validFrom,
    Expression<String>? validTo,
    Expression<bool>? isCancelled,
    Expression<bool>? isDeleted,
    Expression<BigInt>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (userId != null) 'user_id': userId,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (classroom != null) 'classroom': classroom,
      if (lessonType != null) 'lesson_type': lessonType,
      if (topic != null) 'topic': topic,
      if (isEvenWeek != null) 'is_even_week': isEvenWeek,
      if (specificDate != null) 'specific_date': specificDate,
      if (validFrom != null) 'valid_from': validFrom,
      if (validTo != null) 'valid_to': validTo,
      if (isCancelled != null) 'is_cancelled': isCancelled,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonsCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectId,
    Value<String>? userId,
    Value<int>? dayOfWeek,
    Value<String>? startTime,
    Value<String>? endTime,
    Value<String?>? classroom,
    Value<String>? lessonType,
    Value<String?>? topic,
    Value<bool?>? isEvenWeek,
    Value<String?>? specificDate,
    Value<String?>? validFrom,
    Value<String?>? validTo,
    Value<bool>? isCancelled,
    Value<bool>? isDeleted,
    Value<BigInt>? updatedAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LessonsCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      userId: userId ?? this.userId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      classroom: classroom ?? this.classroom,
      lessonType: lessonType ?? this.lessonType,
      topic: topic ?? this.topic,
      isEvenWeek: isEvenWeek ?? this.isEvenWeek,
      specificDate: specificDate ?? this.specificDate,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      isCancelled: isCancelled ?? this.isCancelled,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (classroom.present) {
      map['classroom'] = Variable<String>(classroom.value);
    }
    if (lessonType.present) {
      map['lesson_type'] = Variable<String>(lessonType.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (isEvenWeek.present) {
      map['is_even_week'] = Variable<bool>(isEvenWeek.value);
    }
    if (specificDate.present) {
      map['specific_date'] = Variable<String>(specificDate.value);
    }
    if (validFrom.present) {
      map['valid_from'] = Variable<String>(validFrom.value);
    }
    if (validTo.present) {
      map['valid_to'] = Variable<String>(validTo.value);
    }
    if (isCancelled.present) {
      map['is_cancelled'] = Variable<bool>(isCancelled.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<BigInt>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonsCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('userId: $userId, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('classroom: $classroom, ')
          ..write('lessonType: $lessonType, ')
          ..write('topic: $topic, ')
          ..write('isEvenWeek: $isEvenWeek, ')
          ..write('specificDate: $specificDate, ')
          ..write('validFrom: $validFrom, ')
          ..write('validTo: $validTo, ')
          ..write('isCancelled: $isCancelled, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectTitleMeta = const VerificationMeta(
    'subjectTitle',
  );
  @override
  late final GeneratedColumn<String> subjectTitle = GeneratedColumn<String>(
    'subject_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<BigInt> dueDate = GeneratedColumn<BigInt>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('inbox'),
  );
  static const VerificationMeta _isGroupMeta = const VerificationMeta(
    'isGroup',
  );
  @override
  late final GeneratedColumn<bool> isGroup = GeneratedColumn<bool>(
    'is_group',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_group" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<String> sourceMessageId = GeneratedColumn<String>(
    'source_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTaskIdMeta = const VerificationMeta(
    'sourceTaskId',
  );
  @override
  late final GeneratedColumn<String> sourceTaskId = GeneratedColumn<String>(
    'source_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAt = GeneratedColumn<BigInt>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    groupId,
    subjectId,
    subjectTitle,
    title,
    description,
    dueDate,
    priority,
    status,
    isGroup,
    sourceMessageId,
    sourceTaskId,
    isDeleted,
    updatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('subject_title')) {
      context.handle(
        _subjectTitleMeta,
        subjectTitle.isAcceptableOrUnknown(
          data['subject_title']!,
          _subjectTitleMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_group')) {
      context.handle(
        _isGroupMeta,
        isGroup.isAcceptableOrUnknown(data['is_group']!, _isGroupMeta),
      );
    }
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('source_task_id')) {
      context.handle(
        _sourceTaskIdMeta,
        sourceTaskId.isAcceptableOrUnknown(
          data['source_task_id']!,
          _sourceTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      subjectTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_title'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}due_date'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_group'],
      )!,
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_message_id'],
      ),
      sourceTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_task_id'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String userId;
  final String? groupId;
  final String? subjectId;
  final String? subjectTitle;
  final String title;
  final String? description;
  final BigInt? dueDate;
  final int priority;
  final String status;
  final bool isGroup;
  final String? sourceMessageId;
  final String? sourceTaskId;
  final bool isDeleted;
  final BigInt updatedAt;
  final String syncStatus;
  const Task({
    required this.id,
    required this.userId,
    this.groupId,
    this.subjectId,
    this.subjectTitle,
    required this.title,
    this.description,
    this.dueDate,
    required this.priority,
    required this.status,
    required this.isGroup,
    this.sourceMessageId,
    this.sourceTaskId,
    required this.isDeleted,
    required this.updatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    if (!nullToAbsent || subjectTitle != null) {
      map['subject_title'] = Variable<String>(subjectTitle);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<BigInt>(dueDate);
    }
    map['priority'] = Variable<int>(priority);
    map['status'] = Variable<String>(status);
    map['is_group'] = Variable<bool>(isGroup);
    if (!nullToAbsent || sourceMessageId != null) {
      map['source_message_id'] = Variable<String>(sourceMessageId);
    }
    if (!nullToAbsent || sourceTaskId != null) {
      map['source_task_id'] = Variable<String>(sourceTaskId);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['updated_at'] = Variable<BigInt>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      userId: Value(userId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      subjectTitle: subjectTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectTitle),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      priority: Value(priority),
      status: Value(status),
      isGroup: Value(isGroup),
      sourceMessageId: sourceMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMessageId),
      sourceTaskId: sourceTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTaskId),
      isDeleted: Value(isDeleted),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      subjectTitle: serializer.fromJson<String?>(json['subjectTitle']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      dueDate: serializer.fromJson<BigInt?>(json['dueDate']),
      priority: serializer.fromJson<int>(json['priority']),
      status: serializer.fromJson<String>(json['status']),
      isGroup: serializer.fromJson<bool>(json['isGroup']),
      sourceMessageId: serializer.fromJson<String?>(json['sourceMessageId']),
      sourceTaskId: serializer.fromJson<String?>(json['sourceTaskId']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<BigInt>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'groupId': serializer.toJson<String?>(groupId),
      'subjectId': serializer.toJson<String?>(subjectId),
      'subjectTitle': serializer.toJson<String?>(subjectTitle),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'dueDate': serializer.toJson<BigInt?>(dueDate),
      'priority': serializer.toJson<int>(priority),
      'status': serializer.toJson<String>(status),
      'isGroup': serializer.toJson<bool>(isGroup),
      'sourceMessageId': serializer.toJson<String?>(sourceMessageId),
      'sourceTaskId': serializer.toJson<String?>(sourceTaskId),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<BigInt>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    Value<String?> groupId = const Value.absent(),
    Value<String?> subjectId = const Value.absent(),
    Value<String?> subjectTitle = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    Value<BigInt?> dueDate = const Value.absent(),
    int? priority,
    String? status,
    bool? isGroup,
    Value<String?> sourceMessageId = const Value.absent(),
    Value<String?> sourceTaskId = const Value.absent(),
    bool? isDeleted,
    BigInt? updatedAt,
    String? syncStatus,
  }) => Task(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    groupId: groupId.present ? groupId.value : this.groupId,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    subjectTitle: subjectTitle.present ? subjectTitle.value : this.subjectTitle,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    isGroup: isGroup ?? this.isGroup,
    sourceMessageId: sourceMessageId.present
        ? sourceMessageId.value
        : this.sourceMessageId,
    sourceTaskId: sourceTaskId.present ? sourceTaskId.value : this.sourceTaskId,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      subjectTitle: data.subjectTitle.present
          ? data.subjectTitle.value
          : this.subjectTitle,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      isGroup: data.isGroup.present ? data.isGroup.value : this.isGroup,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      sourceTaskId: data.sourceTaskId.present
          ? data.sourceTaskId.value
          : this.sourceTaskId,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('groupId: $groupId, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectTitle: $subjectTitle, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('dueDate: $dueDate, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('isGroup: $isGroup, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('sourceTaskId: $sourceTaskId, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    groupId,
    subjectId,
    subjectTitle,
    title,
    description,
    dueDate,
    priority,
    status,
    isGroup,
    sourceMessageId,
    sourceTaskId,
    isDeleted,
    updatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.groupId == this.groupId &&
          other.subjectId == this.subjectId &&
          other.subjectTitle == this.subjectTitle &&
          other.title == this.title &&
          other.description == this.description &&
          other.dueDate == this.dueDate &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.isGroup == this.isGroup &&
          other.sourceMessageId == this.sourceMessageId &&
          other.sourceTaskId == this.sourceTaskId &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> groupId;
  final Value<String?> subjectId;
  final Value<String?> subjectTitle;
  final Value<String> title;
  final Value<String?> description;
  final Value<BigInt?> dueDate;
  final Value<int> priority;
  final Value<String> status;
  final Value<bool> isGroup;
  final Value<String?> sourceMessageId;
  final Value<String?> sourceTaskId;
  final Value<bool> isDeleted;
  final Value<BigInt> updatedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.subjectTitle = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.sourceTaskId = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String userId,
    this.groupId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.subjectTitle = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.sourceTaskId = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required BigInt updatedAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? groupId,
    Expression<String>? subjectId,
    Expression<String>? subjectTitle,
    Expression<String>? title,
    Expression<String>? description,
    Expression<BigInt>? dueDate,
    Expression<int>? priority,
    Expression<String>? status,
    Expression<bool>? isGroup,
    Expression<String>? sourceMessageId,
    Expression<String>? sourceTaskId,
    Expression<bool>? isDeleted,
    Expression<BigInt>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (groupId != null) 'group_id': groupId,
      if (subjectId != null) 'subject_id': subjectId,
      if (subjectTitle != null) 'subject_title': subjectTitle,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (dueDate != null) 'due_date': dueDate,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (isGroup != null) 'is_group': isGroup,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (sourceTaskId != null) 'source_task_id': sourceTaskId,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? groupId,
    Value<String?>? subjectId,
    Value<String?>? subjectTitle,
    Value<String>? title,
    Value<String?>? description,
    Value<BigInt?>? dueDate,
    Value<int>? priority,
    Value<String>? status,
    Value<bool>? isGroup,
    Value<String?>? sourceMessageId,
    Value<String?>? sourceTaskId,
    Value<bool>? isDeleted,
    Value<BigInt>? updatedAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      subjectId: subjectId ?? this.subjectId,
      subjectTitle: subjectTitle ?? this.subjectTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isGroup: isGroup ?? this.isGroup,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      sourceTaskId: sourceTaskId ?? this.sourceTaskId,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (subjectTitle.present) {
      map['subject_title'] = Variable<String>(subjectTitle.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<BigInt>(dueDate.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isGroup.present) {
      map['is_group'] = Variable<bool>(isGroup.value);
    }
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<String>(sourceMessageId.value);
    }
    if (sourceTaskId.present) {
      map['source_task_id'] = Variable<String>(sourceTaskId.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<BigInt>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('groupId: $groupId, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectTitle: $subjectTitle, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('dueDate: $dueDate, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('isGroup: $isGroup, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('sourceTaskId: $sourceTaskId, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtasksTable extends Subtasks with TableInfo<$SubtasksTable, Subtask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<BigInt> updatedAt = GeneratedColumn<BigInt>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    userId,
    title,
    isDone,
    position,
    isDeleted,
    updatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subtask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subtask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subtask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $SubtasksTable createAlias(String alias) {
    return $SubtasksTable(attachedDatabase, alias);
  }
}

class Subtask extends DataClass implements Insertable<Subtask> {
  final String id;
  final String taskId;
  final String userId;
  final String title;
  final bool isDone;
  final int position;
  final bool isDeleted;
  final BigInt updatedAt;
  final String syncStatus;
  const Subtask({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.title,
    required this.isDone,
    required this.position,
    required this.isDeleted,
    required this.updatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['user_id'] = Variable<String>(userId);
    map['title'] = Variable<String>(title);
    map['is_done'] = Variable<bool>(isDone);
    map['position'] = Variable<int>(position);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['updated_at'] = Variable<BigInt>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  SubtasksCompanion toCompanion(bool nullToAbsent) {
    return SubtasksCompanion(
      id: Value(id),
      taskId: Value(taskId),
      userId: Value(userId),
      title: Value(title),
      isDone: Value(isDone),
      position: Value(position),
      isDeleted: Value(isDeleted),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Subtask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subtask(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      userId: serializer.fromJson<String>(json['userId']),
      title: serializer.fromJson<String>(json['title']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      position: serializer.fromJson<int>(json['position']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<BigInt>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'userId': serializer.toJson<String>(userId),
      'title': serializer.toJson<String>(title),
      'isDone': serializer.toJson<bool>(isDone),
      'position': serializer.toJson<int>(position),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<BigInt>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Subtask copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? title,
    bool? isDone,
    int? position,
    bool? isDeleted,
    BigInt? updatedAt,
    String? syncStatus,
  }) => Subtask(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    position: position ?? this.position,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Subtask copyWithCompanion(SubtasksCompanion data) {
    return Subtask(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      userId: data.userId.present ? data.userId.value : this.userId,
      title: data.title.present ? data.title.value : this.title,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      position: data.position.present ? data.position.value : this.position,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subtask(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('position: $position, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    userId,
    title,
    isDone,
    position,
    isDeleted,
    updatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subtask &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.userId == this.userId &&
          other.title == this.title &&
          other.isDone == this.isDone &&
          other.position == this.position &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus);
}

class SubtasksCompanion extends UpdateCompanion<Subtask> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> userId;
  final Value<String> title;
  final Value<bool> isDone;
  final Value<int> position;
  final Value<bool> isDeleted;
  final Value<BigInt> updatedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const SubtasksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
    this.position = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtasksCompanion.insert({
    required String id,
    required String taskId,
    required String userId,
    required String title,
    this.isDone = const Value.absent(),
    this.position = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required BigInt updatedAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       userId = Value(userId),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<Subtask> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? userId,
    Expression<String>? title,
    Expression<bool>? isDone,
    Expression<int>? position,
    Expression<bool>? isDeleted,
    Expression<BigInt>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (userId != null) 'user_id': userId,
      if (title != null) 'title': title,
      if (isDone != null) 'is_done': isDone,
      if (position != null) 'position': position,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtasksCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? userId,
    Value<String>? title,
    Value<bool>? isDone,
    Value<int>? position,
    Value<bool>? isDeleted,
    Value<BigInt>? updatedAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return SubtasksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      position: position ?? this.position,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<BigInt>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtasksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('position: $position, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 120),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<BigInt> createdAt = GeneratedColumn<BigInt>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    senderId,
    senderName,
    messageType,
    content,
    payloadJson,
    isPinned,
    createdAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    } else if (isInserting) {
      context.missing(_senderNameMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      )!,
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}created_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String messageType;
  final String content;
  final String? payloadJson;
  final bool isPinned;
  final BigInt createdAt;
  final String syncStatus;
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.content,
    this.payloadJson,
    required this.isPinned,
    required this.createdAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['sender_id'] = Variable<String>(senderId);
    map['sender_name'] = Variable<String>(senderName);
    map['message_type'] = Variable<String>(messageType);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['created_at'] = Variable<BigInt>(createdAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      senderId: Value(senderId),
      senderName: Value(senderName),
      messageType: Value(messageType),
      content: Value(content),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      isPinned: Value(isPinned),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      senderName: serializer.fromJson<String>(json['senderName']),
      messageType: serializer.fromJson<String>(json['messageType']),
      content: serializer.fromJson<String>(json['content']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      createdAt: serializer.fromJson<BigInt>(json['createdAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'senderId': serializer.toJson<String>(senderId),
      'senderName': serializer.toJson<String>(senderName),
      'messageType': serializer.toJson<String>(messageType),
      'content': serializer.toJson<String>(content),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'isPinned': serializer.toJson<bool>(isPinned),
      'createdAt': serializer.toJson<BigInt>(createdAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? messageType,
    String? content,
    Value<String?> payloadJson = const Value.absent(),
    bool? isPinned,
    BigInt? createdAt,
    String? syncStatus,
  }) => ChatMessage(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    senderId: senderId ?? this.senderId,
    senderName: senderName ?? this.senderName,
    messageType: messageType ?? this.messageType,
    content: content ?? this.content,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      content: data.content.present ? data.content.value : this.content,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('messageType: $messageType, ')
          ..write('content: $content, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    senderId,
    senderName,
    messageType,
    content,
    payloadJson,
    isPinned,
    createdAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.senderId == this.senderId &&
          other.senderName == this.senderName &&
          other.messageType == this.messageType &&
          other.content == this.content &&
          other.payloadJson == this.payloadJson &&
          other.isPinned == this.isPinned &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> senderId;
  final Value<String> senderName;
  final Value<String> messageType;
  final Value<String> content;
  final Value<String?> payloadJson;
  final Value<bool> isPinned;
  final Value<BigInt> createdAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.senderName = const Value.absent(),
    this.messageType = const Value.absent(),
    this.content = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String groupId,
    required String senderId,
    required String senderName,
    this.messageType = const Value.absent(),
    required String content,
    this.payloadJson = const Value.absent(),
    this.isPinned = const Value.absent(),
    required BigInt createdAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       senderId = Value(senderId),
       senderName = Value(senderName),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? senderId,
    Expression<String>? senderName,
    Expression<String>? messageType,
    Expression<String>? content,
    Expression<String>? payloadJson,
    Expression<bool>? isPinned,
    Expression<BigInt>? createdAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (senderId != null) 'sender_id': senderId,
      if (senderName != null) 'sender_name': senderName,
      if (messageType != null) 'message_type': messageType,
      if (content != null) 'content': content,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (isPinned != null) 'is_pinned': isPinned,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? senderId,
    Value<String>? senderName,
    Value<String>? messageType,
    Value<String>? content,
    Value<String?>? payloadJson,
    Value<bool>? isPinned,
    Value<BigInt>? createdAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      payloadJson: payloadJson ?? this.payloadJson,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<BigInt>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('senderId: $senderId, ')
          ..write('senderName: $senderName, ')
          ..write('messageType: $messageType, ')
          ..write('content: $content, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 255),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 512),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<BigInt> fileSize = GeneratedColumn<BigInt>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<BigInt> createdAt = GeneratedColumn<BigInt>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    messageId,
    fileName,
    relativePath,
    fileSize,
    mimeType,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}file_size'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String? taskId;
  final String? messageId;
  final String fileName;
  final String relativePath;
  final BigInt fileSize;
  final String? mimeType;
  final BigInt createdAt;
  const Attachment({
    required this.id,
    this.taskId,
    this.messageId,
    required this.fileName,
    required this.relativePath,
    required this.fileSize,
    this.mimeType,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || messageId != null) {
      map['message_id'] = Variable<String>(messageId);
    }
    map['file_name'] = Variable<String>(fileName);
    map['relative_path'] = Variable<String>(relativePath);
    map['file_size'] = Variable<BigInt>(fileSize);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    map['created_at'] = Variable<BigInt>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      messageId: messageId == null && nullToAbsent
          ? const Value.absent()
          : Value(messageId),
      fileName: Value(fileName),
      relativePath: Value(relativePath),
      fileSize: Value(fileSize),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      createdAt: Value(createdAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      messageId: serializer.fromJson<String?>(json['messageId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      fileSize: serializer.fromJson<BigInt>(json['fileSize']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      createdAt: serializer.fromJson<BigInt>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String?>(taskId),
      'messageId': serializer.toJson<String?>(messageId),
      'fileName': serializer.toJson<String>(fileName),
      'relativePath': serializer.toJson<String>(relativePath),
      'fileSize': serializer.toJson<BigInt>(fileSize),
      'mimeType': serializer.toJson<String?>(mimeType),
      'createdAt': serializer.toJson<BigInt>(createdAt),
    };
  }

  Attachment copyWith({
    String? id,
    Value<String?> taskId = const Value.absent(),
    Value<String?> messageId = const Value.absent(),
    String? fileName,
    String? relativePath,
    BigInt? fileSize,
    Value<String?> mimeType = const Value.absent(),
    BigInt? createdAt,
  }) => Attachment(
    id: id ?? this.id,
    taskId: taskId.present ? taskId.value : this.taskId,
    messageId: messageId.present ? messageId.value : this.messageId,
    fileName: fileName ?? this.fileName,
    relativePath: relativePath ?? this.relativePath,
    fileSize: fileSize ?? this.fileSize,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    createdAt: createdAt ?? this.createdAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('messageId: $messageId, ')
          ..write('fileName: $fileName, ')
          ..write('relativePath: $relativePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    messageId,
    fileName,
    relativePath,
    fileSize,
    mimeType,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.messageId == this.messageId &&
          other.fileName == this.fileName &&
          other.relativePath == this.relativePath &&
          other.fileSize == this.fileSize &&
          other.mimeType == this.mimeType &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String?> taskId;
  final Value<String?> messageId;
  final Value<String> fileName;
  final Value<String> relativePath;
  final Value<BigInt> fileSize;
  final Value<String?> mimeType;
  final Value<BigInt> createdAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    this.taskId = const Value.absent(),
    this.messageId = const Value.absent(),
    required String fileName,
    required String relativePath,
    required BigInt fileSize,
    this.mimeType = const Value.absent(),
    required BigInt createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fileName = Value(fileName),
       relativePath = Value(relativePath),
       fileSize = Value(fileSize),
       createdAt = Value(createdAt);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? messageId,
    Expression<String>? fileName,
    Expression<String>? relativePath,
    Expression<BigInt>? fileSize,
    Expression<String>? mimeType,
    Expression<BigInt>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (messageId != null) 'message_id': messageId,
      if (fileName != null) 'file_name': fileName,
      if (relativePath != null) 'relative_path': relativePath,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? taskId,
    Value<String?>? messageId,
    Value<String>? fileName,
    Value<String>? relativePath,
    Value<BigInt>? fileSize,
    Value<String?>? mimeType,
    Value<BigInt>? createdAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      messageId: messageId ?? this.messageId,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<BigInt>(fileSize.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<BigInt>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('messageId: $messageId, ')
          ..write('fileName: $fileName, ')
          ..write('relativePath: $relativePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('mimeType: $mimeType, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $LessonsTable lessons = $LessonsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $SubtasksTable subtasks = $SubtasksTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    subjects,
    lessons,
    tasks,
    subtasks,
    chatMessages,
    attachments,
  ];
}

typedef $$SubjectsTableCreateCompanionBuilder = SubjectsCompanion Function({
  required String id,
  required String userId,
  required String title,
  Value<String?> teacherName,
  Value<String?> colorHex,
  Value<bool> isDeleted,
  required BigInt updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$SubjectsTableUpdateCompanionBuilder = SubjectsCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> title,
  Value<String?> teacherName,
  Value<String?> colorHex,
  Value<bool> isDeleted,
  Value<BigInt> updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});

class $$SubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teacherName => $composableBuilder(
    column: $table.teacherName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teacherName => $composableBuilder(
    column: $table.teacherName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get teacherName => $composableBuilder(
    column: $table.teacherName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<BigInt> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$SubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectsTable,
          Subject,
          $$SubjectsTableFilterComposer,
          $$SubjectsTableOrderingComposer,
          $$SubjectsTableAnnotationComposer,
          $$SubjectsTableCreateCompanionBuilder,
          $$SubjectsTableUpdateCompanionBuilder,
          (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
          Subject,
          PrefetchHooks Function()
        > {
  $$SubjectsTableTableManager(_$AppDatabase db, $SubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> teacherName = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<BigInt> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion(
                id: id,
                userId: userId,
                title: title,
                teacherName: teacherName,
                colorHex: colorHex,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String title,
                Value<String?> teacherName = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required BigInt updatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion.insert(
                id: id,
                userId: userId,
                title: title,
                teacherName: teacherName,
                colorHex: colorHex,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubjectsTable, Subject>(table),
                  BaseReferences<_$AppDatabase, $SubjectsTable, Subject>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectsTable,
      Subject,
      $$SubjectsTableFilterComposer,
      $$SubjectsTableOrderingComposer,
      $$SubjectsTableAnnotationComposer,
      $$SubjectsTableCreateCompanionBuilder,
      $$SubjectsTableUpdateCompanionBuilder,
      (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
      Subject,
      PrefetchHooks Function()
    >;
typedef $$LessonsTableCreateCompanionBuilder = LessonsCompanion Function({
  required String id,
  required String subjectId,
  required String userId,
  required int dayOfWeek,
  required String startTime,
  required String endTime,
  Value<String?> classroom,
  Value<String> lessonType,
  Value<String?> topic,
  Value<bool?> isEvenWeek,
  Value<String?> specificDate,
  Value<String?> validFrom,
  Value<String?> validTo,
  Value<bool> isCancelled,
  Value<bool> isDeleted,
  required BigInt updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$LessonsTableUpdateCompanionBuilder = LessonsCompanion Function({
  Value<String> id,
  Value<String> subjectId,
  Value<String> userId,
  Value<int> dayOfWeek,
  Value<String> startTime,
  Value<String> endTime,
  Value<String?> classroom,
  Value<String> lessonType,
  Value<String?> topic,
  Value<bool?> isEvenWeek,
  Value<String?> specificDate,
  Value<String?> validFrom,
  Value<String?> validTo,
  Value<bool> isCancelled,
  Value<bool> isDeleted,
  Value<BigInt> updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});

class $$LessonsTableFilterComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classroom => $composableBuilder(
    column: $table.classroom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonType => $composableBuilder(
    column: $table.lessonType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEvenWeek => $composableBuilder(
    column: $table.isEvenWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get specificDate => $composableBuilder(
    column: $table.specificDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validTo => $composableBuilder(
    column: $table.validTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonsTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classroom => $composableBuilder(
    column: $table.classroom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonType => $composableBuilder(
    column: $table.lessonType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEvenWeek => $composableBuilder(
    column: $table.isEvenWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get specificDate => $composableBuilder(
    column: $table.specificDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validTo => $composableBuilder(
    column: $table.validTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get classroom =>
      $composableBuilder(column: $table.classroom, builder: (column) => column);

  GeneratedColumn<String> get lessonType => $composableBuilder(
    column: $table.lessonType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<bool> get isEvenWeek => $composableBuilder(
    column: $table.isEvenWeek,
    builder: (column) => column,
  );

  GeneratedColumn<String> get specificDate => $composableBuilder(
    column: $table.specificDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get validFrom =>
      $composableBuilder(column: $table.validFrom, builder: (column) => column);

  GeneratedColumn<String> get validTo =>
      $composableBuilder(column: $table.validTo, builder: (column) => column);

  GeneratedColumn<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<BigInt> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$LessonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonsTable,
          Lesson,
          $$LessonsTableFilterComposer,
          $$LessonsTableOrderingComposer,
          $$LessonsTableAnnotationComposer,
          $$LessonsTableCreateCompanionBuilder,
          $$LessonsTableUpdateCompanionBuilder,
          (Lesson, BaseReferences<_$AppDatabase, $LessonsTable, Lesson>),
          Lesson,
          PrefetchHooks Function()
        > {
  $$LessonsTableTableManager(_$AppDatabase db, $LessonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> dayOfWeek = const Value.absent(),
                Value<String> startTime = const Value.absent(),
                Value<String> endTime = const Value.absent(),
                Value<String?> classroom = const Value.absent(),
                Value<String> lessonType = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<bool?> isEvenWeek = const Value.absent(),
                Value<String?> specificDate = const Value.absent(),
                Value<String?> validFrom = const Value.absent(),
                Value<String?> validTo = const Value.absent(),
                Value<bool> isCancelled = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<BigInt> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonsCompanion(
                id: id,
                subjectId: subjectId,
                userId: userId,
                dayOfWeek: dayOfWeek,
                startTime: startTime,
                endTime: endTime,
                classroom: classroom,
                lessonType: lessonType,
                topic: topic,
                isEvenWeek: isEvenWeek,
                specificDate: specificDate,
                validFrom: validFrom,
                validTo: validTo,
                isCancelled: isCancelled,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectId,
                required String userId,
                required int dayOfWeek,
                required String startTime,
                required String endTime,
                Value<String?> classroom = const Value.absent(),
                Value<String> lessonType = const Value.absent(),
                Value<String?> topic = const Value.absent(),
                Value<bool?> isEvenWeek = const Value.absent(),
                Value<String?> specificDate = const Value.absent(),
                Value<String?> validFrom = const Value.absent(),
                Value<String?> validTo = const Value.absent(),
                Value<bool> isCancelled = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required BigInt updatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonsCompanion.insert(
                id: id,
                subjectId: subjectId,
                userId: userId,
                dayOfWeek: dayOfWeek,
                startTime: startTime,
                endTime: endTime,
                classroom: classroom,
                lessonType: lessonType,
                topic: topic,
                isEvenWeek: isEvenWeek,
                specificDate: specificDate,
                validFrom: validFrom,
                validTo: validTo,
                isCancelled: isCancelled,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LessonsTable, Lesson>(table),
                  BaseReferences<_$AppDatabase, $LessonsTable, Lesson>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonsTable,
      Lesson,
      $$LessonsTableFilterComposer,
      $$LessonsTableOrderingComposer,
      $$LessonsTableAnnotationComposer,
      $$LessonsTableCreateCompanionBuilder,
      $$LessonsTableUpdateCompanionBuilder,
      (Lesson, BaseReferences<_$AppDatabase, $LessonsTable, Lesson>),
      Lesson,
      PrefetchHooks Function()
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String id,
  required String userId,
  Value<String?> groupId,
  Value<String?> subjectId,
  Value<String?> subjectTitle,
  required String title,
  Value<String?> description,
  Value<BigInt?> dueDate,
  Value<int> priority,
  Value<String> status,
  Value<bool> isGroup,
  Value<String?> sourceMessageId,
  Value<String?> sourceTaskId,
  Value<bool> isDeleted,
  required BigInt updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String?> groupId,
  Value<String?> subjectId,
  Value<String?> subjectTitle,
  Value<String> title,
  Value<String?> description,
  Value<BigInt?> dueDate,
  Value<int> priority,
  Value<String> status,
  Value<bool> isGroup,
  Value<String?> sourceMessageId,
  Value<String?> sourceTaskId,
  Value<bool> isDeleted,
  Value<BigInt> updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectTitle => $composableBuilder(
    column: $table.subjectTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTaskId => $composableBuilder(
    column: $table.sourceTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectTitle => $composableBuilder(
    column: $table.subjectTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTaskId => $composableBuilder(
    column: $table.sourceTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get subjectTitle => $composableBuilder(
    column: $table.subjectTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isGroup =>
      $composableBuilder(column: $table.isGroup, builder: (column) => column);

  GeneratedColumn<String> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTaskId => $composableBuilder(
    column: $table.sourceTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<BigInt> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
          Task,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String?> subjectTitle = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<BigInt?> dueDate = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<String?> sourceMessageId = const Value.absent(),
                Value<String?> sourceTaskId = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<BigInt> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                userId: userId,
                groupId: groupId,
                subjectId: subjectId,
                subjectTitle: subjectTitle,
                title: title,
                description: description,
                dueDate: dueDate,
                priority: priority,
                status: status,
                isGroup: isGroup,
                sourceMessageId: sourceMessageId,
                sourceTaskId: sourceTaskId,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> groupId = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String?> subjectTitle = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<BigInt?> dueDate = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<String?> sourceMessageId = const Value.absent(),
                Value<String?> sourceTaskId = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required BigInt updatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                userId: userId,
                groupId: groupId,
                subjectId: subjectId,
                subjectTitle: subjectTitle,
                title: title,
                description: description,
                dueDate: dueDate,
                priority: priority,
                status: status,
                isGroup: isGroup,
                sourceMessageId: sourceMessageId,
                sourceTaskId: sourceTaskId,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, Task>(table),
                  BaseReferences<_$AppDatabase, $TasksTable, Task>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
      Task,
      PrefetchHooks Function()
    >;
typedef $$SubtasksTableCreateCompanionBuilder = SubtasksCompanion Function({
  required String id,
  required String taskId,
  required String userId,
  required String title,
  Value<bool> isDone,
  Value<int> position,
  Value<bool> isDeleted,
  required BigInt updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$SubtasksTableUpdateCompanionBuilder = SubtasksCompanion Function({
  Value<String> id,
  Value<String> taskId,
  Value<String> userId,
  Value<String> title,
  Value<bool> isDone,
  Value<int> position,
  Value<bool> isDeleted,
  Value<BigInt> updatedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});

class $$SubtasksTableFilterComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubtasksTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubtasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<BigInt> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$SubtasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubtasksTable,
          Subtask,
          $$SubtasksTableFilterComposer,
          $$SubtasksTableOrderingComposer,
          $$SubtasksTableAnnotationComposer,
          $$SubtasksTableCreateCompanionBuilder,
          $$SubtasksTableUpdateCompanionBuilder,
          (Subtask, BaseReferences<_$AppDatabase, $SubtasksTable, Subtask>),
          Subtask,
          PrefetchHooks Function()
        > {
  $$SubtasksTableTableManager(_$AppDatabase db, $SubtasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<BigInt> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion(
                id: id,
                taskId: taskId,
                userId: userId,
                title: title,
                isDone: isDone,
                position: position,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String userId,
                required String title,
                Value<bool> isDone = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required BigInt updatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion.insert(
                id: id,
                taskId: taskId,
                userId: userId,
                title: title,
                isDone: isDone,
                position: position,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubtasksTable, Subtask>(table),
                  BaseReferences<_$AppDatabase, $SubtasksTable, Subtask>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubtasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubtasksTable,
      Subtask,
      $$SubtasksTableFilterComposer,
      $$SubtasksTableOrderingComposer,
      $$SubtasksTableAnnotationComposer,
      $$SubtasksTableCreateCompanionBuilder,
      $$SubtasksTableUpdateCompanionBuilder,
      (Subtask, BaseReferences<_$AppDatabase, $SubtasksTable, Subtask>),
      Subtask,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String id,
      required String groupId,
      required String senderId,
      required String senderName,
      Value<String> messageType,
      required String content,
      Value<String?> payloadJson,
      Value<bool> isPinned,
      required BigInt createdAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> senderId,
      Value<String> senderName,
      Value<String> messageType,
      Value<String> content,
      Value<String?> payloadJson,
      Value<bool> isPinned,
      Value<BigInt> createdAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<BigInt> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessage,
            BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
          ),
          ChatMessage,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> senderName = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<BigInt> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                groupId: groupId,
                senderId: senderId,
                senderName: senderName,
                messageType: messageType,
                content: content,
                payloadJson: payloadJson,
                isPinned: isPinned,
                createdAt: createdAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String senderId,
                required String senderName,
                Value<String> messageType = const Value.absent(),
                required String content,
                Value<String?> payloadJson = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                required BigInt createdAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                groupId: groupId,
                senderId: senderId,
                senderName: senderName,
                messageType: messageType,
                content: content,
                payloadJson: payloadJson,
                isPinned: isPinned,
                createdAt: createdAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatMessagesTable,
                    ChatMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessage,
        BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
      ),
      ChatMessage,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      Value<String?> taskId,
      Value<String?> messageId,
      required String fileName,
      required String relativePath,
      required BigInt fileSize,
      Value<String?> mimeType,
      required BigInt createdAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String?> taskId,
      Value<String?> messageId,
      Value<String> fileName,
      Value<String> relativePath,
      Value<BigInt> fileSize,
      Value<String?> mimeType,
      Value<BigInt> createdAt,
      Value<int> rowid,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<BigInt> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            Attachment,
            BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
          ),
          Attachment,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> messageId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<BigInt> fileSize = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<BigInt> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                taskId: taskId,
                messageId: messageId,
                fileName: fileName,
                relativePath: relativePath,
                fileSize: fileSize,
                mimeType: mimeType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> taskId = const Value.absent(),
                Value<String?> messageId = const Value.absent(),
                required String fileName,
                required String relativePath,
                required BigInt fileSize,
                Value<String?> mimeType = const Value.absent(),
                required BigInt createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                taskId: taskId,
                messageId: messageId,
                fileName: fileName,
                relativePath: relativePath,
                fileSize: fileSize,
                mimeType: mimeType,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, Attachment>(table),
                  BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        Attachment,
        BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
      ),
      Attachment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db, _db.subjects);
  $$LessonsTableTableManager get lessons =>
      $$LessonsTableTableManager(_db, _db.lessons);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db, _db.subtasks);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
}
