/// Which kind of student uses the app. Decides the sign-in method and the
/// feature set; the design is the same for both.
///
/// - [university]: LMS (Moodle) import, credits, GPA analytics, campus map.
/// - [college]: SmartNation grades and assignments, group timetable from the
///   college's Excel files.
enum AppEdition {
  university,
  college;

  /// `users.edition` on the server; unknown values mean [university].
  static AppEdition fromName(String? name) =>
      name == 'college' ? AppEdition.college : AppEdition.university;

  /// Edition of a signed-in user (`user['edition']`), or [fallback] for the
  /// guest user, which has none.
  static AppEdition ofUser(Map<String, dynamic> user, {AppEdition? fallback}) {
    final name = user['edition'];
    if (name is String) return fromName(name);
    return fallback ?? AppEdition.university;
  }

  bool get isCollege => this == AppEdition.college;
}
