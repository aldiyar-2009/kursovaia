import 'package:drift/drift.dart';
import 'package:studyplan/core/database/app_database.dart';

class SubjectDao {
  final AppDatabase db;
  SubjectDao(this.db);

  Stream<List<Subject>> watchAllSubjects(String userId) {
    return (db.select(db.subjects)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  Future<List<Subject>> getAllSubjects(String userId) {
    return (db.select(db.subjects)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
        .get();
  }

  Future<void> insertSubject(SubjectsCompanion subject) {
    return db.into(db.subjects).insert(subject);
  }

  Future<void> updateSubject(SubjectsCompanion subject) {
    return db.update(db.subjects).replace(subject);
  }

  Future<void> softDeleteSubject(String id, int nowMs) {
    return (db.update(db.subjects)..where((t) => t.id.equals(id))).write(
      SubjectsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending_delete'),
        updatedAt: Value(BigInt.from(nowMs)),
      ),
    );
  }
}
