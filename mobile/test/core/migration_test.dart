import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';

/// Exact DDL produced by schema version 1 of [AppDatabase].
const _v1Schema = <String>[
  'CREATE TABLE "subjects" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "title" TEXT NOT NULL, "teacher_name" TEXT NULL, "color_hex" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "updated_at" INTEGER NOT NULL, "sync_status" TEXT NOT NULL DEFAULT \'synced\', PRIMARY KEY ("id"))',
  'CREATE TABLE "lessons" ("id" TEXT NOT NULL, "subject_id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "day_of_week" INTEGER NOT NULL, "start_time" TEXT NOT NULL, "end_time" TEXT NOT NULL, "classroom" TEXT NULL, "lesson_type" TEXT NOT NULL DEFAULT \'lecture\', "topic" TEXT NULL, "is_even_week" INTEGER NULL CHECK ("is_even_week" IN (0, 1)), "specific_date" TEXT NULL, "valid_from" TEXT NULL, "valid_to" TEXT NULL, "is_cancelled" INTEGER NOT NULL DEFAULT 0 CHECK ("is_cancelled" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "updated_at" INTEGER NOT NULL, "sync_status" TEXT NOT NULL DEFAULT \'synced\', PRIMARY KEY ("id"))',
  'CREATE TABLE "tasks" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "group_id" TEXT NULL, "subject_id" TEXT NULL, "subject_title" TEXT NULL, "title" TEXT NOT NULL, "description" TEXT NULL, "due_date" INTEGER NULL, "priority" INTEGER NOT NULL DEFAULT 3, "status" TEXT NOT NULL DEFAULT \'inbox\', "is_group" INTEGER NOT NULL DEFAULT 0 CHECK ("is_group" IN (0, 1)), "source_message_id" TEXT NULL, "source_task_id" TEXT NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "updated_at" INTEGER NOT NULL, "sync_status" TEXT NOT NULL DEFAULT \'synced\', PRIMARY KEY ("id"))',
  'CREATE TABLE "subtasks" ("id" TEXT NOT NULL, "task_id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "title" TEXT NOT NULL, "is_done" INTEGER NOT NULL DEFAULT 0 CHECK ("is_done" IN (0, 1)), "position" INTEGER NOT NULL DEFAULT 0, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "updated_at" INTEGER NOT NULL, "sync_status" TEXT NOT NULL DEFAULT \'synced\', PRIMARY KEY ("id"))',
  'CREATE TABLE "chat_messages" ("id" TEXT NOT NULL, "group_id" TEXT NOT NULL, "sender_id" TEXT NOT NULL, "sender_name" TEXT NOT NULL, "message_type" TEXT NOT NULL DEFAULT \'text\', "content" TEXT NOT NULL, "payload_json" TEXT NULL, "is_pinned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_pinned" IN (0, 1)), "created_at" INTEGER NOT NULL, "sync_status" TEXT NOT NULL DEFAULT \'synced\', PRIMARY KEY ("id"))',
  'CREATE TABLE "attachments" ("id" TEXT NOT NULL, "task_id" TEXT NULL, "message_id" TEXT NULL, "file_name" TEXT NOT NULL, "relative_path" TEXT NOT NULL, "file_size" INTEGER NOT NULL, "mime_type" TEXT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
];

void main() {
  test('schema version is 2', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
    await db.close();
  });

  test('v1 database upgrades to v2: LMS tables created, chat dropped, data kept', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      for (final stmt in _v1Schema) {
        raw.execute(stmt);
      }
      raw.execute(
        "INSERT INTO subjects (id, user_id, title, updated_at, sync_status) "
        "VALUES ('s1', 'u1', 'Math', 1, 'synced')",
      );
      raw.execute(
        "INSERT INTO chat_messages (id, group_id, sender_id, sender_name, content, created_at) "
        "VALUES ('m1', 'g1', 'u1', 'A', 'hi', 1)",
      );
      raw.execute('PRAGMA user_version = 1');
    });

    final db = AppDatabase.forTesting(executor);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((r) => r.read<String>('name'))
        .get();
    expect(tables, containsAll(['lms_courses', 'lms_events', 'lms_materials', 'subjects']));
    expect(tables, isNot(contains('chat_messages')));

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);

    final subjects = await db.select(db.subjects).get();
    expect(subjects.single.title, 'Math');

    // New tables are usable after the upgrade.
    await db.into(db.lmsCourses).insert(LmsCoursesCompanion.insert(
          id: 'c1',
          userId: 'u1',
          title: 'Algebra',
          updatedAt: BigInt.from(1),
        ));
    expect((await db.select(db.lmsCourses).get()).single.credits, 5);

    await db.close();
  });
}
