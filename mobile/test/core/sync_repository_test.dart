import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/sync/sync_repository.dart';

void main() {
  late AppDatabase db;
  late ApiClient apiClient;
  late SyncRepository repo;
  Map<String, dynamic>? sentPayload;
  late Map<String, dynamic> serverChanges;
  late List<Map<String, dynamic>> serverRejected;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    apiClient = ApiClient(baseUrl: 'http://test.local/api');
    sentPayload = null;
    serverChanges = {};
    serverRejected = [];
    apiClient.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentPayload = options.data as Map<String, dynamic>;
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'server_time': 5000, 'changes': serverChanges, 'rejected': serverRejected},
      ));
    }));
    repo = SyncRepository(db: db, apiClient: apiClient);
  });

  tearDown(() async {
    await db.close();
  });

  test('pushes pending LMS rows with server snake_case keys and no chat', () async {
    await db.into(db.lmsCourses).insert(LmsCoursesCompanion.insert(
          id: 'c1',
          userId: 'u1',
          source: const Value('lms'),
          lmsCourseId: const Value(42),
          subjectId: const Value('s1'),
          classification: const Value('inprogress'),
          title: 'Algebra',
          teacherName: const Value('Teacher A'),
          credits: const Value(6),
          registerMidterm: const Value(80.0),
          registerEndterm: const Value(90.0),
          finalExam: const Value(null),
          total: const Value(85.5),
          gradeItemsJson: const Value('[]'),
          importedAt: Value(BigInt.from(100)),
          updatedAt: BigInt.from(200),
          syncStatus: const Value('pending_create'),
        ));
    await db.into(db.lmsEvents).insert(LmsEventsCompanion.insert(
          id: 'e1',
          userId: 'u1',
          lmsEventId: const Value(7),
          lmsCourseId: const Value(42),
          title: 'Quiz',
          courseTitle: const Value('Algebra'),
          eventType: const Value('deadline'),
          moduleName: const Value('quiz'),
          startsAt: BigInt.from(3000),
          durationMin: const Value(30),
          location: const Value('C1.1'),
          url: const Value('https://lms/q'),
          isDone: const Value(true),
          importedAt: Value(BigInt.from(100)),
          updatedAt: BigInt.from(200),
          syncStatus: const Value('pending_update'),
        ));
    await db.into(db.lmsMaterials).insert(LmsMaterialsCompanion.insert(
          id: 'm1',
          userId: 'u1',
          lmsModuleId: const Value(9),
          lmsCourseId: const Value(42),
          courseTitle: const Value('Algebra'),
          sectionTitle: const Value('Week 1'),
          title: 'Slides',
          materialType: const Value('file'),
          url: const Value('https://lms/f'),
          importedAt: Value(BigInt.from(100)),
          updatedAt: BigInt.from(200),
          syncStatus: const Value('pending_create'),
        ));

    expect(await repo.getPendingChangesCount('u1'), 3);

    await repo.syncWithServer('u1');

    final changes = sentPayload!['changes'] as Map<String, dynamic>;
    expect(changes.containsKey('chat_messages'), isFalse);
    expect((changes['lms_courses'] as List).single, {
      'id': 'c1',
      'source': 'lms',
      'lms_course_id': 42,
      'subject_id': 's1',
      'classification': 'inprogress',
      'title': 'Algebra',
      'teacher_name': 'Teacher A',
      'credits': 6,
      'register_midterm': 80.0,
      'register_endterm': 90.0,
      'final_exam': null,
      'total': 85.5,
      'grade_items_json': '[]',
      'imported_at': 100,
      'is_deleted': false,
      'updated_at': 200,
    });
    expect((changes['lms_events'] as List).single, {
      'id': 'e1',
      'lms_event_id': 7,
      'lms_course_id': 42,
      'title': 'Quiz',
      'course_title': 'Algebra',
      'event_type': 'deadline',
      'module_name': 'quiz',
      'starts_at': 3000,
      'duration_min': 30,
      'location': 'C1.1',
      'url': 'https://lms/q',
      'is_done': true,
      'imported_at': 100,
      'is_deleted': false,
      'updated_at': 200,
    });
    expect((changes['lms_materials'] as List).single, {
      'id': 'm1',
      'lms_module_id': 9,
      'lms_course_id': 42,
      'course_title': 'Algebra',
      'section_title': 'Week 1',
      'title': 'Slides',
      'material_type': 'file',
      'url': 'https://lms/f',
      'imported_at': 100,
      'is_deleted': false,
      'updated_at': 200,
    });

    expect(await repo.getPendingChangesCount('u1'), 0);
  });

  test('pulls LMS rows from server and applies tombstones', () async {
    await db.into(db.lmsMaterials).insert(LmsMaterialsCompanion.insert(
          id: 'm-old',
          userId: 'u1',
          title: 'Old',
          updatedAt: BigInt.from(1),
        ));
    serverChanges = {
      'lms_courses': [
        {
          'id': 'c1',
          'user_id': 'u1',
          'source': 'manual',
          'lms_course_id': null,
          'subject_id': null,
          'classification': null,
          'title': 'Physics',
          'teacher_name': null,
          'credits': 4,
          'register_midterm': 70,
          'register_endterm': null,
          'final_exam': null,
          'total': null,
          'grade_items_json': null,
          'imported_at': null,
          'is_deleted': false,
          'updated_at': 300,
        }
      ],
      'lms_events': [
        {
          'id': 'e1',
          'user_id': 'u1',
          'lms_event_id': 5,
          'lms_course_id': 42,
          'title': 'Lab',
          'course_title': 'Physics',
          'event_type': 'class',
          'module_name': 'attendance',
          'starts_at': 4000,
          'duration_min': 90,
          'location': 'C1.2',
          'url': null,
          'is_done': 1,
          'imported_at': 10,
          'is_deleted': 0,
          'updated_at': 300,
        }
      ],
      'lms_materials': [
        {'id': 'm-old', 'is_deleted': true, 'updated_at': 300, 'title': 'Old'}
      ],
    };

    await repo.syncWithServer('u1');

    final course = (await db.select(db.lmsCourses).get()).single;
    expect(course.title, 'Physics');
    expect(course.credits, 4);
    expect(course.registerMidterm, 70.0);
    expect(course.total, isNull);
    expect(course.syncStatus, 'synced');
    expect(course.userId, 'u1');

    final event = (await db.select(db.lmsEvents).get()).single;
    expect(event.eventType, 'class');
    expect(event.isDone, isTrue);
    expect(event.startsAt, BigInt.from(4000));
    expect(event.durationMin, 90);

    expect(await db.select(db.lmsMaterials).get(), isEmpty);
  });

  group('rejected rows', () {
    Future<void> insertTask(String id, {bool deleted = false, String status = 'pending_update'}) =>
        db.into(db.tasks).insert(TasksCompanion.insert(
              id: id,
              userId: 'u1',
              title: 'Task $id',
              isDeleted: Value(deleted),
              updatedAt: BigInt.from(200),
              syncStatus: Value(status),
            ));

    Future<Task?> task(String id) =>
        (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

    test('rows rejected for a non-stale reason stay pending; others become synced', () async {
      await insertTask('ok');
      await insertTask('bad');
      await insertTask('bad-deleted', deleted: true);
      serverRejected = [
        {'table': 'tasks', 'id': 'bad', 'reason': 'forbidden'},
        {'table': 'tasks', 'id': 'bad-deleted', 'reason': 'title is required'},
        // Same id in another table must not affect the task.
        {'table': 'subjects', 'id': 'ok', 'reason': 'forbidden'},
      ];

      final result = await repo.syncWithServer('u1');

      expect((await task('ok'))!.syncStatus, 'synced');
      expect((await task('bad'))!.syncStatus, 'pending_update');
      final keptTombstone = await task('bad-deleted');
      expect(keptTombstone, isNotNull, reason: 'a rejected delete must not be dropped locally');
      expect(keptTombstone!.syncStatus, 'pending_update');
      expect(await repo.getPendingChangesCount('u1'), 2);
      expect(result.appliedCount, 1);
    });

    test('stale rejection marks the row synced and accepts the server version', () async {
      await insertTask('t1');
      serverRejected = [
        {'table': 'tasks', 'id': 't1', 'reason': 'stale'},
      ];
      serverChanges = {
        'tasks': [
          {
            'id': 't1',
            'user_id': 'u1',
            'title': 'Server title',
            'priority': 2,
            'status': 'done',
            'is_group': false,
            'is_deleted': false,
            'updated_at': 900,
          }
        ],
      };

      await repo.syncWithServer('u1');

      final row = (await task('t1'))!;
      expect(row.syncStatus, 'synced');
      expect(row.title, 'Server title');
      expect(row.updatedAt, BigInt.from(900));
      expect(await repo.getPendingChangesCount('u1'), 0);
    });

    test('a rejected row is pushed again on the next sync', () async {
      await insertTask('bad');
      serverRejected = [
        {'table': 'tasks', 'id': 'bad', 'reason': 'subject_id not found'},
      ];
      await repo.syncWithServer('u1');

      serverRejected = [];
      await repo.syncWithServer('u1');

      final pushed = (sentPayload!['changes'] as Map<String, dynamic>)['tasks'] as List;
      expect(pushed.map((t) => (t as Map)['id']), ['bad']);
      expect((await task('bad'))!.syncStatus, 'synced');
    });
  });

  test('resetCursor sets last_synced_at back to 0', () async {
    await repo.syncWithServer('u1');
    expect(await repo.getLastSyncedAt(), 5000);

    await repo.resetCursor();
    expect(await repo.getLastSyncedAt(), 0);

    await repo.syncWithServer('u1');
    expect(sentPayload!['last_synced_at'], 0);
  });
}
