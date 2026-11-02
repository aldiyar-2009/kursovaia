import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/utils/uuid_util.dart';

/// Prefix of the cached event lists (`events.cache.upcoming|past`); removed
/// on logout together with the other caches.
const kEventsCachePrefix = 'events.cache';

/// Event from a public Telegram channel (`GET /api/events`).
class CampusEvent {
  final int id;
  final String title;
  final String? text;
  final DateTime startsAt;
  final bool hasTime;
  final String? place;

  /// Registration / tickets.
  final String? link;
  final String? imageUrl;
  final String? postUrl;

  const CampusEvent({
    required this.id,
    required this.title,
    this.text,
    required this.startsAt,
    this.hasTime = false,
    this.place,
    this.link,
    this.imageUrl,
    this.postUrl,
  });

  factory CampusEvent.fromJson(Map<String, dynamic> j) {
    final starts = j['starts_at'];
    return CampusEvent(
      id: (j['id'] as num).toInt(),
      title: (j['title'] ?? '').toString(),
      text: j['text'] as String?,
      startsAt: starts is num
          ? DateTime.fromMillisecondsSinceEpoch(starts.toInt())
          : DateTime.parse(starts.toString()).toLocal(),
      hasTime: j['has_time'] == true,
      place: j['place'] as String?,
      link: j['link'] as String?,
      imageUrl: j['image_url'] as String?,
      postUrl: j['post_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'starts_at': startsAt.millisecondsSinceEpoch,
    'has_time': hasTime,
    'place': place,
    'link': link,
    'image_url': imageUrl,
    'post_url': postUrl,
  };

  /// Due date of the task «add to my plan»: the start time, or the end of
  /// the day when the post has no time.
  DateTime get planDate => hasTime
      ? startsAt
      : DateTime(startsAt.year, startsAt.month, startsAt.day, 23, 59);

  /// Id of the task created from this event for [userId].
  String taskId(String userId) => UuidUtil.stable(userId, 'event:$id');
}

class EventsResult {
  final List<CampusEvent> events;
  final bool fromCache;

  const EventsResult(this.events, {this.fromCache = false});
}

class EventsRepository {
  final ApiClient apiClient;

  EventsRepository(this.apiClient);

  /// [past] = finished events, newest first; otherwise upcoming, nearest
  /// first. Falls back to the cached list without network.
  Future<EventsResult> load({bool past = false, int limit = 50}) async {
    final key = '$kEventsCachePrefix.${past ? 'past' : 'upcoming'}';
    try {
      final res = await apiClient.dio.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {'scope': past ? 'past' : 'upcoming', 'limit': limit},
      );
      final events = [
        for (final e in (res.data?['events'] as List?) ?? const [])
          CampusEvent.fromJson(e as Map<String, dynamic>),
      ];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode([for (final e in events) e.toJson()]),
      );
      return EventsResult(events);
    } catch (_) {
      return EventsResult(await _cached(key), fromCache: true);
    }
  }

  Future<List<CampusEvent>> _cached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return const [];
      return [
        for (final e in jsonDecode(raw) as List)
          CampusEvent.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }
}
