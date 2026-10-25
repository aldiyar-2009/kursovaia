import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';

/// SharedPreferences keys holding the signed-in user's data. All of them are
/// removed on logout so the next account starts clean.
const kSessionPrefsKeys = <String>[
  'jwt_token',
  'user_data',
  'group_data',
  // Sync cursor: the next account must pull everything from 0.
  kSyncCursorPrefsKey,
  'lms.profile',
  'group_members_cache',
  'pending_invite_code',
];

/// Prefix of the per-group materials caches (`group_materials_cache_<id>`).
const kGroupMaterialsCachePrefix = 'group_materials_cache';

/// Removes every user-scoped SharedPreferences entry ([kSessionPrefsKeys] and
/// all `group_materials_cache*` keys). App settings (theme, language, server
/// URL) are kept.
Future<void> clearSessionPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in kSessionPrefsKeys) {
    await prefs.remove(key);
  }
  final caches = prefs
      .getKeys()
      .where((k) => k.startsWith(kGroupMaterialsCachePrefix))
      .toList();
  for (final key in caches) {
    await prefs.remove(key);
  }
}

/// Deletes all rows of every local table in one transaction. Rows are
/// filtered by `userId` on read, but the previous user's data must not stay
/// on a shared device.
Future<void> wipeLocalDatabase(AppDatabase db) async {
  await db.transaction(() async {
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
  });
}

/// Local part of logout: user prefs and the local database. Failures of one
/// step do not stop the others.
///
/// [clearWebSession] is for the LMS web-login cookies (to be wired to
/// `clearLmsWebSession()` from the LMS feature).
Future<void> clearLocalSession(
  AppDatabase db, {
  Future<void> Function()? clearWebSession,
}) async {
  try {
    await clearSessionPrefs();
  } catch (_) {}
  try {
    await wipeLocalDatabase(db);
  } catch (_) {}
  if (clearWebSession != null) {
    try {
      await clearWebSession();
    } catch (_) {}
  }
}

/// After joining, creating or leaving a group: the cursor goes back to 0 so
/// the next sync also pulls group tasks published before the change, and
/// that sync starts. The bloc resets the cursor again right before syncing,
/// so a sync already in flight cannot overwrite the reset.
///
/// The cursor reset is a local equivalent of `SyncRepository.resetCursor()`.
Future<void> resyncAfterGroupChange(SyncBloc bloc) async {
  try {
    await resetSyncCursor();
  } catch (_) {}
  if (!bloc.isClosed) bloc.add(SyncFullResyncRequested());
}
