import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'app_database.g.dart';

// Sync status values: 'synced', 'pending_create', 'pending_update', 'pending_delete'

class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text().withLength(min: 1, max: 160)();
  TextColumn get teacherName => text().nullable().withLength(max: 160)();
  TextColumn get colorHex => text().nullable().withLength(max: 9)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  Int64Column get updatedAt => int64()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Lessons extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  TextColumn get userId => text()();
  IntColumn get dayOfWeek => integer()(); // 1..7 (Monday..Sunday)
  TextColumn get startTime => text().withLength(min: 5, max: 5)(); // HH:mm
  TextColumn get endTime => text().withLength(min: 5, max: 5)(); // HH:mm
  TextColumn get classroom => text().nullable().withLength(max: 64)();
  TextColumn get lessonType => text().withDefault(const Constant('lecture'))(); // lecture | practice | lab
  TextColumn get topic => text().nullable().withLength(max: 255)();
  BoolColumn get isEvenWeek => boolean().nullable()();
  TextColumn get specificDate => text().nullable()(); // YYYY-MM-DD
  TextColumn get validFrom => text().nullable()();
  TextColumn get validTo => text().nullable()();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  Int64Column get updatedAt => int64()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get groupId => text().nullable()();
  TextColumn get subjectId => text().nullable()();
  TextColumn get subjectTitle => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  Int64Column get dueDate => int64().nullable()(); // epoch ms
  IntColumn get priority => integer().withDefault(const Constant(3))(); // 1-P1, 2-P2, 3-P3
  TextColumn get status => text().withDefault(const Constant('inbox'))(); // inbox | in_progress | completed
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  TextColumn get sourceMessageId => text().nullable()();
  TextColumn get sourceTaskId => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  Int64Column get updatedAt => int64()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get userId => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  Int64Column get updatedAt => int64()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get senderId => text()();
  TextColumn get senderName => text().withLength(max: 120)();
  TextColumn get messageType => text().withDefault(const Constant('text'))(); // text | schedule_update | homework | file
  TextColumn get content => text()();
  TextColumn get payloadJson => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  Int64Column get createdAt => int64()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get messageId => text().nullable()();
  TextColumn get fileName => text().withLength(max: 255)();
  TextColumn get relativePath => text().withLength(max: 512)();
  Int64Column get fileSize => int64()();
  TextColumn get mimeType => text().nullable().withLength(max: 100)();
  Int64Column get createdAt => int64()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Subjects, Lessons, Tasks, Subtasks, ChatMessages, Attachments])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'studyplan_local',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (result) {
          if (result.missingFeatures.isNotEmpty) {
            debugPrint('Using ${result.chosenImplementation} due to missing browser features: ${result.missingFeatures}');
          }
        },
      ),
    );
  }
}
