import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';

class SyncRepository {
  final AppDatabase db;
  final ApiClient apiClient;

  SyncRepository({required this.db, required this.apiClient});

  static const String _lastSyncedKey = 'studyplan_last_synced_at';

  Future<int> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncedKey) ?? 0;
  }

  Future<void> setLastSyncedAt(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncedKey, timestamp);
  }

  Future<List<Subject>> _pendingSubjects(String userId) => (db.select(db.subjects)
        ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
      .get();

  Future<List<Lesson>> _pendingLessons(String userId) => (db.select(db.lessons)
        ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
      .get();

  Future<List<Task>> _pendingTasks(String userId) => (db.select(db.tasks)
        ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
      .get();

  Future<List<Subtask>> _pendingSubtasks(String userId) => (db.select(db.subtasks)
        ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
      .get();

  Future<List<LmsCourse>> _pendingLmsCourses(String userId) => (db.select(db.lmsCourses)
        ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
      .get();

  Future<List<LmsEvent>> _pendingLmsEvents(String userId) => (db.select(db.lmsEvents)
        ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
      .get();

  Future<List<LmsMaterial>> _pendingLmsMaterials(String userId) => (db.select(db.lmsMaterials)
        ..where((t) => t.userId.equals(userId) & t.syncStatus.isNotValue('synced')))
      .get();

  Future<int> getPendingChangesCount(String userId) async {
    final counts = await Future.wait([
      _pendingSubjects(userId).then((l) => l.length),
      _pendingLessons(userId).then((l) => l.length),
      _pendingTasks(userId).then((l) => l.length),
      _pendingSubtasks(userId).then((l) => l.length),
      _pendingLmsCourses(userId).then((l) => l.length),
      _pendingLmsEvents(userId).then((l) => l.length),
      _pendingLmsMaterials(userId).then((l) => l.length),
    ]);
    return counts.fold<int>(0, (sum, c) => sum + c);
  }

  /// Pushes local pending changes and pulls latest server records
  Future<({int serverTime, int appliedCount})> syncWithServer(String userId) async {
    final lastSyncedAt = await getLastSyncedAt();

    // 1. Collect pending changes from Drift
    final pendingSubjects = await _pendingSubjects(userId);
    final pendingLessons = await _pendingLessons(userId);
    final pendingTasks = await _pendingTasks(userId);
    final pendingSubtasks = await _pendingSubtasks(userId);
    final pendingLmsCourses = await _pendingLmsCourses(userId);
    final pendingLmsEvents = await _pendingLmsEvents(userId);
    final pendingLmsMaterials = await _pendingLmsMaterials(userId);

    final payload = {
      'last_synced_at': lastSyncedAt,
      'changes': {
        'subjects': pendingSubjects.map((s) => {
              'id': s.id,
              'title': s.title,
              'teacher_name': s.teacherName,
              'color_hex': s.colorHex,
              'is_deleted': s.isDeleted,
              'updated_at': s.updatedAt.toInt(),
            }).toList(),
        'lessons': pendingLessons.map((l) => {
              'id': l.id,
              'subject_id': l.subjectId,
              'day_of_week': l.dayOfWeek,
              'start_time': l.startTime,
              'end_time': l.endTime,
              'classroom': l.classroom,
              'lesson_type': l.lessonType,
              'topic': l.topic,
              'is_even_week': l.isEvenWeek,
              'specific_date': l.specificDate,
              'valid_from': l.validFrom,
              'valid_to': l.validTo,
              'is_cancelled': l.isCancelled,
              'is_deleted': l.isDeleted,
              'updated_at': l.updatedAt.toInt(),
            }).toList(),
        'tasks': pendingTasks.map((t) => {
              'id': t.id,
              'group_id': t.groupId,
              'subject_id': t.subjectId,
              'subject_title': t.subjectTitle,
              'title': t.title,
              'description': t.description,
              'due_date': t.dueDate?.toInt(),
              'priority': t.priority,
              'status': t.status,
              'is_group': t.isGroup,
              'source_message_id': t.sourceMessageId,
              'source_task_id': t.sourceTaskId,
              'is_deleted': t.isDeleted,
              'updated_at': t.updatedAt.toInt(),
            }).toList(),
        'subtasks': pendingSubtasks.map((st) => {
              'id': st.id,
              'task_id': st.taskId,
              'title': st.title,
              'is_done': st.isDone,
              'position': st.position,
              'is_deleted': st.isDeleted,
              'updated_at': st.updatedAt.toInt(),
            }).toList(),
        'lms_courses': pendingLmsCourses.map((c) => {
              'id': c.id,
              'source': c.source,
              'lms_course_id': c.lmsCourseId,
              'subject_id': c.subjectId,
              'classification': c.classification,
              'title': c.title,
              'teacher_name': c.teacherName,
              'credits': c.credits,
              'register_midterm': c.registerMidterm,
              'register_endterm': c.registerEndterm,
              'final_exam': c.finalExam,
              'total': c.total,
              'grade_items_json': c.gradeItemsJson,
              'imported_at': c.importedAt?.toInt(),
              'is_deleted': c.isDeleted,
              'updated_at': c.updatedAt.toInt(),
            }).toList(),
        'lms_events': pendingLmsEvents.map((e) => {
              'id': e.id,
              'lms_event_id': e.lmsEventId,
              'lms_course_id': e.lmsCourseId,
              'title': e.title,
              'course_title': e.courseTitle,
              'event_type': e.eventType,
              'module_name': e.moduleName,
              'starts_at': e.startsAt.toInt(),
              'duration_min': e.durationMin,
              'location': e.location,
              'url': e.url,
              'is_done': e.isDone,
              'imported_at': e.importedAt?.toInt(),
              'is_deleted': e.isDeleted,
              'updated_at': e.updatedAt.toInt(),
            }).toList(),
        'lms_materials': pendingLmsMaterials.map((m) => {
              'id': m.id,
              'lms_module_id': m.lmsModuleId,
              'lms_course_id': m.lmsCourseId,
              'course_title': m.courseTitle,
              'section_title': m.sectionTitle,
              'title': m.title,
              'material_type': m.materialType,
              'url': m.url,
              'imported_at': m.importedAt?.toInt(),
              'is_deleted': m.isDeleted,
              'updated_at': m.updatedAt.toInt(),
            }).toList(),
      },
    };

    final response = await apiClient.dio.post('/sync', data: payload);
    final data = response.data as Map<String, dynamic>;
    final serverTime = data['server_time'] as int;
    final changes = data['changes'] as Map<String, dynamic>;

    // 2. Mark local pending items as synced in transaction
    await db.transaction(() async {
      // Subjects
      for (final s in pendingSubjects) {
        if (s.isDeleted) {
          await (db.delete(db.subjects)..where((t) => t.id.equals(s.id))).go();
        } else {
          await (db.update(db.subjects)..where((t) => t.id.equals(s.id))).write(
            const SubjectsCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // Lessons
      for (final l in pendingLessons) {
        if (l.isDeleted) {
          await (db.delete(db.lessons)..where((t) => t.id.equals(l.id))).go();
        } else {
          await (db.update(db.lessons)..where((t) => t.id.equals(l.id))).write(
            const LessonsCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // Tasks
      for (final t in pendingTasks) {
        if (t.isDeleted) {
          await (db.delete(db.tasks)..where((row) => row.id.equals(t.id))).go();
        } else {
          await (db.update(db.tasks)..where((row) => row.id.equals(t.id))).write(
            const TasksCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // Subtasks
      for (final st in pendingSubtasks) {
        if (st.isDeleted) {
          await (db.delete(db.subtasks)..where((t) => t.id.equals(st.id))).go();
        } else {
          await (db.update(db.subtasks)..where((t) => t.id.equals(st.id))).write(
            const SubtasksCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // LMS courses
      for (final c in pendingLmsCourses) {
        if (c.isDeleted) {
          await (db.delete(db.lmsCourses)..where((t) => t.id.equals(c.id))).go();
        } else {
          await (db.update(db.lmsCourses)..where((t) => t.id.equals(c.id))).write(
            const LmsCoursesCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // LMS events
      for (final e in pendingLmsEvents) {
        if (e.isDeleted) {
          await (db.delete(db.lmsEvents)..where((t) => t.id.equals(e.id))).go();
        } else {
          await (db.update(db.lmsEvents)..where((t) => t.id.equals(e.id))).write(
            const LmsEventsCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // LMS materials
      for (final m in pendingLmsMaterials) {
        if (m.isDeleted) {
          await (db.delete(db.lmsMaterials)..where((t) => t.id.equals(m.id))).go();
        } else {
          await (db.update(db.lmsMaterials)..where((t) => t.id.equals(m.id))).write(
            const LmsMaterialsCompanion(syncStatus: Value('synced')),
          );
        }
      }

      // 3. Apply server changes (Last-Write-Wins pull)
      final serverSubjects = (changes['subjects'] as List<dynamic>? ?? []);
      for (final raw in serverSubjects) {
        final s = raw as Map<String, dynamic>;
        final isDeleted = s['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.subjects)..where((t) => t.id.equals(s['id']))).go();
        } else {
          await db.into(db.subjects).insertOnConflictUpdate(
                SubjectsCompanion(
                  id: Value(s['id']),
                  userId: Value(userId),
                  title: Value(s['title']),
                  teacherName: Value(s['teacher_name']),
                  colorHex: Value(s['color_hex']),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(s['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverLessons = (changes['lessons'] as List<dynamic>? ?? []);
      for (final raw in serverLessons) {
        final l = raw as Map<String, dynamic>;
        final isDeleted = l['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.lessons)..where((t) => t.id.equals(l['id']))).go();
        } else {
          await db.into(db.lessons).insertOnConflictUpdate(
                LessonsCompanion(
                  id: Value(l['id']),
                  subjectId: Value(l['subject_id']),
                  userId: Value(userId),
                  dayOfWeek: Value((l['day_of_week'] as num).toInt()),
                  startTime: Value(l['start_time']),
                  endTime: Value(l['end_time']),
                  classroom: Value(l['classroom']),
                  lessonType: Value(l['lesson_type'] ?? 'lecture'),
                  topic: Value(l['topic']),
                  isEvenWeek: Value(l['is_even_week']),
                  specificDate: Value(l['specific_date']),
                  validFrom: Value(l['valid_from']),
                  validTo: Value(l['valid_to']),
                  isCancelled: Value(l['is_cancelled'] == true),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(l['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverTasks = (changes['tasks'] as List<dynamic>? ?? []);
      for (final raw in serverTasks) {
        final t = raw as Map<String, dynamic>;
        final isDeleted = t['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.tasks)..where((e) => e.id.equals(t['id']))).go();
        } else {
          await db.into(db.tasks).insertOnConflictUpdate(
                TasksCompanion(
                  id: Value(t['id']),
                  userId: Value(t['user_id'] ?? userId),
                  groupId: Value(t['group_id']),
                  subjectId: Value(t['subject_id']),
                  subjectTitle: Value(t['subject_title']),
                  title: Value(t['title']),
                  description: Value(t['description']),
                  dueDate: Value(t['due_date'] != null ? BigInt.from(t['due_date'] as num) : null),
                  priority: Value((t['priority'] as num? ?? 3).toInt()),
                  status: Value(t['status'] ?? 'inbox'),
                  isGroup: Value(t['is_group'] == true),
                  sourceMessageId: Value(t['source_message_id']),
                  sourceTaskId: Value(t['source_task_id']),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(t['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverSubtasks = (changes['subtasks'] as List<dynamic>? ?? []);
      for (final raw in serverSubtasks) {
        final st = raw as Map<String, dynamic>;
        final isDeleted = st['is_deleted'] == true;
        if (isDeleted) {
          await (db.delete(db.subtasks)..where((e) => e.id.equals(st['id']))).go();
        } else {
          await db.into(db.subtasks).insertOnConflictUpdate(
                SubtasksCompanion(
                  id: Value(st['id']),
                  taskId: Value(st['task_id']),
                  userId: Value(userId),
                  title: Value(st['title']),
                  isDone: Value(st['is_done'] == true),
                  position: Value((st['position'] as num? ?? 0).toInt()),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(st['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverLmsCourses = (changes['lms_courses'] as List<dynamic>? ?? []);
      for (final raw in serverLmsCourses) {
        final c = raw as Map<String, dynamic>;
        if (_bool(c['is_deleted'])) {
          await (db.delete(db.lmsCourses)..where((t) => t.id.equals(c['id']))).go();
        } else {
          await db.into(db.lmsCourses).insertOnConflictUpdate(
                LmsCoursesCompanion(
                  id: Value(c['id']),
                  userId: Value(userId),
                  source: Value(c['source'] ?? 'manual'),
                  lmsCourseId: Value(_int(c['lms_course_id'])),
                  subjectId: Value(c['subject_id']),
                  classification: Value(c['classification']),
                  title: Value(c['title']),
                  teacherName: Value(c['teacher_name']),
                  credits: Value(_int(c['credits']) ?? 5),
                  registerMidterm: Value(_double(c['register_midterm'])),
                  registerEndterm: Value(_double(c['register_endterm'])),
                  finalExam: Value(_double(c['final_exam'])),
                  total: Value(_double(c['total'])),
                  gradeItemsJson: Value(c['grade_items_json']),
                  importedAt: Value(_bigInt(c['imported_at'])),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(c['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverLmsEvents = (changes['lms_events'] as List<dynamic>? ?? []);
      for (final raw in serverLmsEvents) {
        final e = raw as Map<String, dynamic>;
        if (_bool(e['is_deleted'])) {
          await (db.delete(db.lmsEvents)..where((t) => t.id.equals(e['id']))).go();
        } else {
          await db.into(db.lmsEvents).insertOnConflictUpdate(
                LmsEventsCompanion(
                  id: Value(e['id']),
                  userId: Value(userId),
                  lmsEventId: Value(_int(e['lms_event_id'])),
                  lmsCourseId: Value(_int(e['lms_course_id'])),
                  title: Value(e['title']),
                  courseTitle: Value(e['course_title']),
                  eventType: Value(e['event_type'] ?? 'other'),
                  moduleName: Value(e['module_name']),
                  startsAt: Value(BigInt.from(e['starts_at'] as num)),
                  durationMin: Value(_int(e['duration_min'])),
                  location: Value(e['location']),
                  url: Value(e['url']),
                  isDone: Value(_bool(e['is_done'])),
                  importedAt: Value(_bigInt(e['imported_at'])),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(e['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }

      final serverLmsMaterials = (changes['lms_materials'] as List<dynamic>? ?? []);
      for (final raw in serverLmsMaterials) {
        final m = raw as Map<String, dynamic>;
        if (_bool(m['is_deleted'])) {
          await (db.delete(db.lmsMaterials)..where((t) => t.id.equals(m['id']))).go();
        } else {
          await db.into(db.lmsMaterials).insertOnConflictUpdate(
                LmsMaterialsCompanion(
                  id: Value(m['id']),
                  userId: Value(userId),
                  lmsModuleId: Value(_int(m['lms_module_id'])),
                  lmsCourseId: Value(_int(m['lms_course_id'])),
                  courseTitle: Value(m['course_title']),
                  sectionTitle: Value(m['section_title']),
                  title: Value(m['title']),
                  materialType: Value(m['material_type'] ?? 'other'),
                  url: Value(m['url']),
                  importedAt: Value(_bigInt(m['imported_at'])),
                  isDeleted: const Value(false),
                  updatedAt: Value(BigInt.from(m['updated_at'] as num)),
                  syncStatus: const Value('synced'),
                ),
              );
        }
      }
    });

    await setLastSyncedAt(serverTime);
    return (
      serverTime: serverTime,
      appliedCount: pendingSubjects.length +
          pendingLessons.length +
          pendingTasks.length +
          pendingSubtasks.length +
          pendingLmsCourses.length +
          pendingLmsEvents.length +
          pendingLmsMaterials.length,
    );
  }

  // Server may return booleans as 0/1 (SQLite) or true/false (PostgreSQL).
  static bool _bool(Object? v) => v == true || v == 1;

  static int? _int(Object? v) => v == null ? null : (v as num).toInt();

  static double? _double(Object? v) => v == null ? null : (v as num).toDouble();

  static BigInt? _bigInt(Object? v) => v == null ? null : BigInt.from(v as num);
}
