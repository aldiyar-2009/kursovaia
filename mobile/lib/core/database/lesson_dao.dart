import 'package:drift/drift.dart';
import 'package:studyplan/core/database/app_database.dart';

class LessonDao {
  final AppDatabase db;
  LessonDao(this.db);

  Stream<List<Lesson>> watchLessonsForDay(String userId, int dayOfWeek) {
    return (db.select(db.lessons)
          ..where((t) =>
              t.userId.equals(userId) &
              t.dayOfWeek.equals(dayOfWeek) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .watch();
  }

  Stream<List<Lesson>> watchAllLessons(String userId) {
    return (db.select(db.lessons)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.dayOfWeek),
            (t) => OrderingTerm.asc(t.startTime),
          ]))
        .watch();
  }

  Future<void> insertLesson(LessonsCompanion lesson) {
    return db.into(db.lessons).insert(lesson);
  }

  Future<void> updateLesson(LessonsCompanion lesson) {
    return db.update(db.lessons).replace(lesson);
  }

  Future<void> softDeleteLesson(String id, int nowMs) {
    return (db.update(db.lessons)..where((t) => t.id.equals(id))).write(
      LessonsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending_delete'),
        updatedAt: Value(BigInt.from(nowMs)),
      ),
    );
  }
}
