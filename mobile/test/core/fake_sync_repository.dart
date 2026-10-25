import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_repository.dart';

/// Sync repository that never talks to a server. It records the sync cursor
/// seen by every sync and then moves it to [serverTime], like a real sync.
class FakeSyncRepository extends SyncRepository {
  FakeSyncRepository(AppDatabase db)
      : super(db: db, apiClient: ApiClient(baseUrl: 'http://test.local/api'));

  /// Cursor value (`last_synced_at`) at the start of each sync.
  final cursorsAtSync = <int>[];

  /// When set, every sync waits for it to complete.
  Completer<void>? gate;

  int serverTime = 1000;

  int get syncCalls => cursorsAtSync.length;

  @override
  Future<({int serverTime, int appliedCount})> syncWithServer(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    cursorsAtSync.add(prefs.getInt(kSyncCursorPrefsKey) ?? 0);
    final wait = gate;
    if (wait != null) await wait.future;
    await prefs.setInt(kSyncCursorPrefsKey, serverTime);
    return (serverTime: serverTime, appliedCount: 0);
  }
}
