import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/features/main_shell/data/session_cleanup.dart';

import '../core/fake_sync_repository.dart';

const _sessionPrefs = <String, Object>{
  'jwt_token': 'jwt',
  'user_data': '{"id":"u1"}',
  'group_data': '{"id":"g1"}',
  'studyplan_last_synced_at': 123456,
  'lms.profile': '{"name":"x"}',
  'group_members_cache': '[]',
  'group_materials_cache_g1': '[]',
  'group_materials_cache_g2': '[]',
  'pending_invite_code': 'ABC123',
};

Future<void> seedRows(AppDatabase db) async {
  await db.into(db.subjects).insert(SubjectsCompanion.insert(
        id: 's1',
        userId: 'u1',
        title: 'Math',
        updatedAt: BigInt.one,
      ));
  await db.into(db.tasks).insert(TasksCompanion.insert(
        id: 't1',
        userId: 'u1',
        title: 'Task',
        updatedAt: BigInt.one,
        syncStatus: const Value('pending_create'),
      ));
  await db.into(db.lmsCourses).insert(LmsCoursesCompanion.insert(
        id: 'c1',
        userId: 'u1',
        title: 'Course',
        updatedAt: BigInt.one,
      ));
}

void main() {
  test('clearLocalSession removes user prefs and keeps app settings',
      () async {
    SharedPreferences.setMockInitialValues({
      ..._sessionPrefs,
      'app_theme_mode': 'dark',
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await clearLocalSession(db);

    final prefs = await SharedPreferences.getInstance();
    for (final key in _sessionPrefs.keys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(prefs.getString('app_theme_mode'), 'dark');
  });

  test('clearLocalSession deletes every row of the local database', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedRows(db);

    var webSessionCleared = false;
    await clearLocalSession(
      db,
      clearWebSession: () async => webSessionCleared = true,
    );

    for (final table in db.allTables) {
      expect(await db.select(table).get(), isEmpty, reason: table.actualTableName);
    }
    expect(webSessionCleared, isTrue);
  });

  test('resyncAfterGroupChange writes cursor 0 and syncs from 0', () async {
    SharedPreferences.setMockInitialValues({kSyncCursorPrefsKey: 777});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FakeSyncRepository(db);
    final bloc = SyncBloc(
      repository: repo,
      userId: 'u1',
      listenToConnectivity: false,
      watchLocalChanges: false,
    );

    await resyncAfterGroupChange(bloc);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(kSyncCursorPrefsKey), 0);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.cursorsAtSync, [0]);
    await bloc.close();
  });
}
