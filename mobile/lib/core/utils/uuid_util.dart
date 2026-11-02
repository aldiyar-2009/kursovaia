import 'package:uuid/uuid.dart';

abstract final class UuidUtil {
  static const _uuid = Uuid();

  static String generate() => _uuid.v4();

  /// Same id for the same user and key on every device (UUID v5), so rows
  /// created from outside data (college timetable, events, assignments) are
  /// updated instead of duplicated when they are added again.
  static String stable(String userId, String key) =>
      _uuid.v5(Namespace.url.value, 'studyplan:$userId:$key');
}
