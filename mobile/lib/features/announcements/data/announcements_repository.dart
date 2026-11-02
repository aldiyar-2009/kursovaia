import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';

/// News published from the admin panel (`GET /announcements`).
class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime? publishedAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final published = json['published_at'];
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      publishedAt: published is num
          ? DateTime.fromMillisecondsSinceEpoch(published.toInt())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'published_at': publishedAt?.millisecondsSinceEpoch,
  };
}

class AnnouncementsResult {
  final List<Announcement> items;

  /// The server could not be reached; [items] come from the local cache.
  final bool fromCache;

  const AnnouncementsResult(this.items, {this.fromCache = false});
}

/// Loads published announcements; the last successful list is cached so the
/// home screen still shows them offline.
class AnnouncementsRepository {
  static const cacheKey = 'announcements_cache';

  final ApiClient apiClient;

  const AnnouncementsRepository(this.apiClient);

  Future<AnnouncementsResult> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await apiClient.dio.get<Map<String, dynamic>>(
        '/announcements',
      );
      final items = (res.data!['announcements'] as List)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
      await prefs.setString(
        cacheKey,
        jsonEncode(items.map((a) => a.toJson()).toList()),
      );
      return AnnouncementsResult(items);
    } catch (_) {
      return AnnouncementsResult(_cached(prefs), fromCache: true);
    }
  }

  static List<Announcement> _cached(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
