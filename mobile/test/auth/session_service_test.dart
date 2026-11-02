import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/features/auth/data/session_service.dart';

import '../group/group_test_utils.dart' show fakeApi;

void main() {
  test('adoptGuestData hands guest rows to the account, keeping them pending', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.tasks).insert(TasksCompanion.insert(
          id: 't1',
          userId: kGuestUserId,
          title: 'Guest task',
          updatedAt: BigInt.one,
          syncStatus: const Value('pending_create'),
        ));
    await db.into(db.subjects).insert(SubjectsCompanion.insert(
          id: 's1',
          userId: 'other',
          title: 'Not mine',
          updatedAt: BigInt.one,
        ));

    await adoptGuestData(db, 'u42');

    final task = await (db.select(db.tasks)..where((t) => t.id.equals('t1'))).getSingle();
    expect(task.userId, 'u42');
    expect(task.syncStatus, 'pending_create');
    final subject = await (db.select(db.subjects)..where((s) => s.id.equals('s1'))).getSingle();
    expect(subject.userId, 'other');
  });

  test('startSession stores the account, resets the cursor and sets the token', () async {
    SharedPreferences.setMockInitialValues({kSyncCursorPrefsKey: 999});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = fakeApi({});

    await startSession(
      const Session(token: 'tkn', user: {'id': 'u1', 'name': 'A', 'is_demo': true}),
      db: db,
      apiClient: api,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jwt_token'), 'tkn');
    expect(prefs.getString('group_data'), isNull);
    expect(prefs.getInt(kSyncCursorPrefsKey), 0);
    expect(api.dio.options.headers['Authorization'], 'Bearer tkn');
    expect(isDemoUser(const {'is_demo': true}), isTrue);
    expect(isGuestUser(guestUser()), isTrue);
  });
}
