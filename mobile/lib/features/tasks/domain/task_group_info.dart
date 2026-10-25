/// The user's group as far as the Tasks screen needs it.
///
/// Built from the `group` map the shell receives (same JSON as
/// SharedPreferences `group_data`): `{id, title, members?: [{id, name}]}`.
class TaskGroupInfo {
  final String id;
  final String? title;
  final Map<String, String> memberNames;

  const TaskGroupInfo({
    required this.id,
    this.title,
    this.memberNames = const {},
  });

  /// Returns null when [json] is null or has no usable id.
  static TaskGroupInfo? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final names = <String, String>{};
    final members = json['members'];
    if (members is List) {
      for (final m in members) {
        if (m is Map && m['id'] is String && m['name'] is String) {
          names[m['id'] as String] = m['name'] as String;
        }
      }
    }
    final title = json['title'];
    return TaskGroupInfo(
      id: id,
      title: title is String && title.isNotEmpty ? title : null,
      memberNames: names,
    );
  }
}
