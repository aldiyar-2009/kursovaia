import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';

/// SharedPreferences keys shared with the rest of the app.
abstract final class GroupPrefs {
  /// The user's group row as returned by the server (read by the shell,
  /// Tasks and the profile).
  static const groupData = 'group_data';

  /// Last known member list `[{id, name}]` for offline viewing.
  static const members = 'group_members_cache';

  /// Invite code taken from a web `/join/<code>` link, consumed by the join
  /// form.
  static const pendingInviteCode = 'pending_invite_code';
}

class GroupMember {
  final String id;
  final String name;

  const GroupMember({required this.id, required this.name});

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id']?.toString() ?? '',
        name: (json['name'] as String?)?.trim() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// The user's group and its members. [group] is null when the user is not in
/// a group.
class GroupSnapshot {
  final Map<String, dynamic>? group;
  final List<GroupMember> members;

  const GroupSnapshot({this.group, this.members = const []});

  String? get title => group?['title'] as String?;
  String? get inviteCode => group?['invite_code'] as String?;
}

enum GroupFailure { codeNotFound, alreadyMember, offline, generic }

class GroupException implements Exception {
  final GroupFailure failure;
  const GroupException(this.failure);

  factory GroupException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return const GroupException(GroupFailure.offline);
    if (status == 404) return const GroupException(GroupFailure.codeNotFound);
    if (status == 409) return const GroupException(GroupFailure.alreadyMember);
    return const GroupException(GroupFailure.generic);
  }

  @override
  String toString() => 'GroupException($failure)';
}

/// Group REST calls (`/groups/*`) plus the local copy in SharedPreferences.
class GroupRepository {
  final ApiClient apiClient;

  GroupRepository(this.apiClient);

  /// `<server>/join/<code>`: the API base URL without its trailing `/api`.
  static String inviteLink(String apiBaseUrl, String code) {
    var base = apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) base = base.substring(0, base.length - 4);
    return '$base/join/$code';
  }

  String inviteLinkFor(String code) =>
      inviteLink(apiClient.dio.options.baseUrl, code);

  /// Group and members saved on this device.
  Future<GroupSnapshot> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? group;
    final raw = prefs.getString(GroupPrefs.groupData);
    if (raw != null) {
      try {
        group = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    var members = const <GroupMember>[];
    final rawMembers = prefs.getString(GroupPrefs.members);
    if (group != null && rawMembers != null) {
      try {
        members = (jsonDecode(rawMembers) as List)
            .whereType<Map<String, dynamic>>()
            .map(GroupMember.fromJson)
            .toList();
      } catch (_) {}
    }
    return GroupSnapshot(group: group, members: members);
  }

  Future<void> _persist(GroupSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    if (snapshot.group == null) {
      await prefs.remove(GroupPrefs.groupData);
      await prefs.remove(GroupPrefs.members);
    } else {
      await prefs.setString(GroupPrefs.groupData, jsonEncode(snapshot.group));
      await prefs.setString(
        GroupPrefs.members,
        jsonEncode(snapshot.members.map((m) => m.toJson()).toList()),
      );
    }
  }

  /// `GET /groups/me`; the result is saved locally.
  Future<GroupSnapshot> refresh() async {
    try {
      final res = await apiClient.dio.get<dynamic>('/groups/me');
      final data = res.data as Map<String, dynamic>;
      final group = data['group'] as Map<String, dynamic>?;
      final members = group == null
          ? const <GroupMember>[]
          : ((data['members'] as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(GroupMember.fromJson)
              .toList();
      final snapshot = GroupSnapshot(group: group, members: members);
      await _persist(snapshot);
      return snapshot;
    } on DioException catch (e) {
      throw GroupException.fromDio(e);
    }
  }

  Future<GroupSnapshot> _mutate(String path, [Object? body]) async {
    try {
      await apiClient.dio.post<dynamic>(path, data: body);
    } on DioException catch (e) {
      throw GroupException.fromDio(e);
    }
    return refresh();
  }

  Future<GroupSnapshot> create(String title) =>
      _mutate('/groups', {'title': title.trim()});

  Future<GroupSnapshot> join(String code) =>
      _mutate('/groups/join', {'invite_code': code.trim().toUpperCase()});

  Future<GroupSnapshot> leave() => _mutate('/groups/leave');

  /// Returns and removes the code saved from a `/join/<code>` link.
  static Future<String?> takePendingInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(GroupPrefs.pendingInviteCode);
    if (code == null) return null;
    await prefs.remove(GroupPrefs.pendingInviteCode);
    return code.trim().isEmpty ? null : code.trim().toUpperCase();
  }

  /// Saves the code from a web `/join/<code>` path, if [path] is one.
  static Future<void> storePendingInviteFromPath(String path) async {
    final match =
        RegExp(r'^/join/([A-Za-z0-9]{4,16})/?$').firstMatch(path);
    if (match == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      GroupPrefs.pendingInviteCode,
      match.group(1)!.toUpperCase(),
    );
  }
}
