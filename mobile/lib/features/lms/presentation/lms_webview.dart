// `flutter_inappwebview` is imported only by the io variant, so it never
// reaches the web build.
export 'lms_webview_common.dart';
export 'lms_webview_stub.dart' if (dart.library.io) 'lms_webview_io.dart';
