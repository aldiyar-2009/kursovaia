import 'package:drift/drift.dart';
import 'package:studyplan/core/database/app_database.dart';

part 'lms_dao.g.dart';

/// Local access to LMS courses, events and materials.
///
/// Every write stamps `updatedAt = now` and a pending `syncStatus`, so the
/// change is pushed on the next `POST /api/sync` (same convention as TaskDao).
@DriftAccessor(tables: [LmsCourses, LmsEvents, LmsMaterials])
class LmsDao extends DatabaseAccessor<AppDatabase> with _$LmsDaoMixin {
  LmsDao(super.attachedDatabase);

  BigInt _now() => BigInt.from(DateTime.now().millisecondsSinceEpoch);

  Stream<List<LmsCourse>> watchCourses(String userId) {
    return (select(lmsCourses)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  Stream<List<LmsEvent>> watchEvents(String userId, {String? type, int? fromMs, int? toMs}) {
    return (select(lmsEvents)
          ..where((t) {
            var predicate = t.userId.equals(userId) & t.isDeleted.equals(false);
            if (type != null) {
              predicate = predicate & t.eventType.equals(type);
            }
            if (fromMs != null) {
              predicate = predicate & t.startsAt.isBiggerOrEqualValue(BigInt.from(fromMs));
            }
            if (toMs != null) {
              predicate = predicate & t.startsAt.isSmallerOrEqualValue(BigInt.from(toMs));
            }
            return predicate;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.startsAt)]))
        .watch();
  }

  Stream<List<LmsMaterial>> watchMaterials(String userId) {
    return (select(lmsMaterials)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.courseTitle),
            (t) => OrderingTerm.asc(t.sectionTitle),
            (t) => OrderingTerm.asc(t.title),
          ]))
        .watch();
  }

  /// Inserts a new course (`pending_create`) or updates an existing one
  /// (`pending_update`; a not-yet-pushed `pending_create` row stays so).
  Future<void> upsertManualCourse(LmsCoursesCompanion course) {
    return transaction(() async {
      final existing = await (select(lmsCourses)..where((t) => t.id.equals(course.id.value)))
          .getSingleOrNull();
      final status = existing == null || existing.syncStatus == 'pending_create'
          ? 'pending_create'
          : 'pending_update';
      await into(lmsCourses).insertOnConflictUpdate(course.copyWith(
        updatedAt: Value(_now()),
        syncStatus: Value(status),
      ));
    });
  }

  Future<void> updateCredits(String id, int credits) {
    return (update(lmsCourses)..where((t) => t.id.equals(id))).write(LmsCoursesCompanion(
      credits: Value(credits),
      updatedAt: Value(_now()),
      syncStatus: const Value('pending_update'),
    ));
  }

  Future<void> setEventDone(String id, bool done) {
    return (update(lmsEvents)..where((t) => t.id.equals(id))).write(LmsEventsCompanion(
      isDone: Value(done),
      updatedAt: Value(_now()),
      syncStatus: const Value('pending_update'),
    ));
  }

  Future<void> softDeleteCourse(String id) {
    return (update(lmsCourses)..where((t) => t.id.equals(id))).write(LmsCoursesCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(_now()),
      syncStatus: const Value('pending_delete'),
    ));
  }
}
