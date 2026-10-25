import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_state.dart';

import 'fake_sync_repository.dart';

Future<void> _settle([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late AppDatabase db;
  late FakeSyncRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({kSyncCursorPrefsKey: 500});
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeSyncRepository(db);
  });

  tearDown(() => db.close());

  SyncBloc makeBloc({Duration debounce = const Duration(seconds: 5)}) =>
      SyncBloc(
        repository: repo,
        userId: 'u1',
        pendingDebounce: debounce,
        listenToConnectivity: false,
      );

  test('resetSyncCursor writes 0 to studyplan_last_synced_at', () async {
    await resetSyncCursor();
    final prefs = await SharedPreferences.getInstance();
    expect(kSyncCursorPrefsKey, 'studyplan_last_synced_at');
    expect(prefs.getInt('studyplan_last_synced_at'), 0);
  });

  test('only one sync runs at a time; triggers meanwhile are ignored',
      () async {
    final bloc = makeBloc();
    repo.gate = Completer<void>();

    bloc
      ..add(SyncTriggered())
      ..add(SyncTriggered())
      ..add(SyncTriggered());
    await _settle();
    expect(repo.syncCalls, 1);
    expect(bloc.isSyncing, isTrue);
    expect(bloc.state.status, SyncStatusState.syncing);

    repo.gate!.complete();
    await _settle();
    expect(repo.syncCalls, 1);
    expect(bloc.isSyncing, isFalse);
    expect(bloc.state.status, SyncStatusState.synced);
    await bloc.close();
  });

  test('a new pending change schedules one debounced sync', () async {
    final bloc = makeBloc(debounce: const Duration(milliseconds: 150));
    await _settle();

    // Two quick local edits: a single sync after the pause.
    await db.into(db.subjects).insert(SubjectsCompanion.insert(
          id: 's1',
          userId: 'u1',
          title: 'Math',
          updatedAt: BigInt.one,
          syncStatus: const Value('pending_create'),
        ));
    await _settle(50);
    await db.into(db.subjects).insert(SubjectsCompanion.insert(
          id: 's2',
          userId: 'u1',
          title: 'Physics',
          updatedAt: BigInt.one,
          syncStatus: const Value('pending_create'),
        ));
    await _settle(50);
    expect(repo.syncCalls, 0);
    expect(bloc.state.pendingCount, 2);

    await _settle(250);
    expect(repo.syncCalls, 1);
    await bloc.close();
  });

  test('a lower pending count does not schedule a sync', () async {
    final bloc = makeBloc(debounce: const Duration(milliseconds: 50));
    await _settle();
    bloc.add(SyncPendingUpdated(0));
    await _settle(150);
    expect(repo.syncCalls, 0);
    await bloc.close();
  });

  test('full resync requested during a sync runs again from cursor 0',
      () async {
    final bloc = makeBloc();
    repo.gate = Completer<void>();
    bloc.add(SyncTriggered());
    await _settle();
    expect(repo.cursorsAtSync, [500]);

    bloc.add(SyncFullResyncRequested());
    await _settle();
    expect(repo.syncCalls, 1);

    // The running sync moves the cursor to the server time; the follow-up
    // sync must still start from 0.
    repo.gate!.complete();
    repo.gate = null;
    await _settle(50);
    expect(repo.cursorsAtSync, [500, 0]);
    await bloc.close();
  });
}
