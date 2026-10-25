/// Platform-neutral pieces of the LMS WebView (no `flutter_inappwebview`
/// import here: this file is reachable from the web build).
library;

const String kLmsHost = 'lms.astanait.edu.kz';

/// Entry point of the Microsoft (OIDC) sign-in for the LMS.
final Uri kLmsLoginUrl =
    Uri.parse('https://$kLmsHost/auth/oidc/?source=loginpage');

/// JS expression that is `true` once the page is a logged-in Moodle page.
const String kLmsSesskeyCheck =
    "typeof M !== 'undefined' && M.cfg && M.cfg.sesskey ? true : false";

/// True for an LMS page outside the login flow, where it makes sense to
/// check for a Moodle session.
bool isLmsAppPage(Uri? url) {
  if (url == null || url.host != kLmsHost) return false;
  final path = url.path;
  return !(path == '/login' ||
      path.startsWith('/login/') ||
      path.startsWith('/auth/'));
}

/// Window of the import: from 1 September of the current academic year
/// (the previous calendar year for January–August) to `now + 183 days`.
({int sinceSec, int untilSec}) lmsImportWindow(DateTime now) {
  final startYear = now.month >= 9 ? now.year : now.year - 1;
  final since = DateTime(startYear, 9, 1);
  final until = now.add(const Duration(days: 183));
  return (
    sinceSec: since.millisecondsSinceEpoch ~/ 1000,
    untilSec: until.millisecondsSinceEpoch ~/ 1000,
  );
}

/// Failure reported by the in-page import script.
class LmsScriptException implements Exception {
  const LmsScriptException(this.message);
  final String message;

  @override
  String toString() => 'LmsScriptException: $message';
}

/// What the import screen needs from the embedded browser.
abstract class LmsWebViewController {
  /// Whether the current page has a Moodle session (`M.cfg.sesskey`).
  Future<bool> hasSesskey();

  /// Runs the import script in the page and returns its JSON string.
  /// Throws [LmsScriptException] when the script fails.
  Future<String> runImport({required int sinceSec, required int untilSec});
}
