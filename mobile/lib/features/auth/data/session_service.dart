import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_edition.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';

/// Local user id of guest mode (no account): rows are stored on the device
/// only and handed over to the account on sign-in ([adoptGuestData]).
const kGuestUserId = 'guest';

Map<String, dynamic> guestUser() => const {
  'id': kGuestUserId,
  'name': null,
  'email': null,
};

bool isGuestUser(Map<String, dynamic> user) => user['id'] == kGuestUserId;

/// Demo accounts are created by `POST /auth/demo` and can be cleared.
bool isDemoUser(Map<String, dynamic> user) => user['is_demo'] == true;

/// Account returned by `/auth/login`, `/auth/register` or `/auth/demo`.
class Session {
  final String token;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? group;

  const Session({required this.token, required this.user, this.group});

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    token: json['token'] as String,
    user: json['user'] as Map<String, dynamic>,
    group: json['group'] as Map<String, dynamic>?,
  );
}

/// Stores [session], hands guest rows over to the account and points the API
/// client at it. The sync cursor is reset so the next sync pulls everything
/// the account already has on the server.
Future<void> startSession(
  Session session, {
  required AppDatabase db,
  required ApiClient apiClient,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('jwt_token', session.token);
  await prefs.setString('user_data', jsonEncode(session.user));
  if (session.group != null) {
    await prefs.setString('group_data', jsonEncode(session.group));
  } else {
    await prefs.remove('group_data');
  }
  await prefs.remove(kGuestModePrefsKey);
  await adoptGuestData(db, session.user['id'] as String);
  await resetSyncCursor();
  apiClient.updateToken(session.token);
}

/// SharedPreferences flag: the user chose «continue without signing in», so
/// the next start opens the guest shell instead of the edition choice.
const kGuestModePrefsKey = 'guest_mode';

Future<void> setGuestMode(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  if (enabled) {
    await prefs.setBool(kGuestModePrefsKey, true);
  } else {
    await prefs.remove(kGuestModePrefsKey);
  }
}

/// Creates a demo account of [edition] filled with sample data on the server.
Future<Session> requestDemoSession(
  ApiClient apiClient, {
  AppEdition edition = AppEdition.university,
}) async {
  final res = await apiClient.dio.post<Map<String, dynamic>>(
    '/auth/demo',
    data: {'edition': edition.name},
  );
  return Session.fromJson(res.data!);
}

/// College sign-in: the server checks the SmartNation login (ИИН or login)
/// and password, keeps them encrypted and refreshes grades by itself.
Future<Session> requestCollegeSession(
  ApiClient apiClient, {
  required String login,
  required String password,
}) async {
  final res = await apiClient.dio.post<Map<String, dynamic>>(
    '/auth/smartnation',
    data: {'login': login, 'password': password},
  );
  return Session.fromJson(res.data!);
}

/// Tables whose rows belong to a user (`user_id`), see `SYNC_ORDER` on the
/// server.
const _userTables = [
  'subjects',
  'lessons',
  'tasks',
  'subtasks',
  'lms_courses',
  'lms_events',
  'lms_materials',
];

/// What the guest entered before signing in becomes the account's data: the
/// rows are still pending, so the first sync uploads them.
Future<void> adoptGuestData(AppDatabase db, String userId) async {
  if (userId == kGuestUserId) return;
  await db.transaction(() async {
    for (final table in _userTables) {
      await db.customUpdate(
        'UPDATE $table SET user_id = ? WHERE user_id = ?',
        variables: [
          Variable.withString(userId),
          Variable.withString(kGuestUserId),
        ],
        updateKind: UpdateKind.update,
      );
    }
  });
}
