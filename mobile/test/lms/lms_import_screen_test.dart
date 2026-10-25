import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/lms/data/lms_importer.dart';
import 'package:studyplan/features/lms/presentation/lms_import_screen.dart';
import 'package:studyplan/features/lms/presentation/lms_webview_common.dart';
import 'package:studyplan/features/lms/presentation/lms_webview_stub.dart'
    as stub;
import 'package:studyplan/l10n/generated/app_localizations.dart';

Widget _app(Widget home, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light(),
      locale: const Locale('ru'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  test('web stub reports the import as unsupported', () {
    expect(stub.isLmsImportSupported, isFalse);
  });

  test('isLmsAppPage accepts LMS pages outside the login flow', () {
    expect(isLmsAppPage(Uri.parse('https://lms.astanait.edu.kz/my/')), isTrue);
    expect(isLmsAppPage(Uri.parse('https://lms.astanait.edu.kz/')), isTrue);
    expect(
      isLmsAppPage(Uri.parse('https://lms.astanait.edu.kz/login/index.php')),
      isFalse,
    );
    expect(
      isLmsAppPage(Uri.parse('https://lms.astanait.edu.kz/auth/oidc/?x=1')),
      isFalse,
    );
    expect(
      isLmsAppPage(Uri.parse('https://login.microsoftonline.com/common')),
      isFalse,
    );
    expect(isLmsAppPage(null), isFalse);
  });

  test('import window starts on 1 September of the academic year', () {
    final oct = lmsImportWindow(DateTime(2026, 10, 26));
    expect(oct.sinceSec, DateTime(2026, 9, 1).millisecondsSinceEpoch ~/ 1000);
    final feb = lmsImportWindow(DateTime(2027, 2, 10));
    expect(feb.sinceSec, DateTime(2026, 9, 1).millisecondsSinceEpoch ~/ 1000);
    expect(
      feb.untilSec,
      DateTime(2027, 2, 10).add(const Duration(days: 183))
              .millisecondsSinceEpoch ~/
          1000,
    );
  });

  testWidgets('intro step shows the privacy sentence and the sign-in button',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(LmsImportScreen(db: db, userId: 'u1')));
    await tester.pump();

    expect(
      find.text('Пароль вводится только на странице Microsoft. '
          'StudyPlan его не видит и не хранит.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Войти через Microsoft'),
        findsOneWidget);
    expect(find.text('Импорт из LMS'), findsOneWidget);
  });

  testWidgets('intro stays in the content column at 1280 px, 44 px buttons',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(LmsImportScreen(db: db, userId: 'u1')));
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Войти через Microsoft');
    expect(tester.getSize(button).width, lessThanOrEqualTo(720));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    expect(tester.getTopLeft(button).dx, (1280 - 720) / 2);
    final close = find.byIcon(Icons.close);
    expect(tester.getSize(close).height, lessThanOrEqualTo(24));
    expect(
      tester.getSize(find.ancestor(of: close, matching: find.byType(IconButton)))
          .height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('result buttons are at least 44 px tall', (tester) async {
    await tester.pumpWidget(_app(
      Scaffold(
        body: LmsImportResultView(
          summary: const LmsImportSummary(
            courses: 1,
            events: 0,
            classes: 0,
            materials: 0,
            errors: {'grades': 'x'},
          ),
          onRetry: () {},
          onDone: () {},
        ),
      ),
    ));
    for (final b in [
      find.widgetWithText(OutlinedButton, 'Повторить'),
      find.widgetWithText(FilledButton, 'Готово'),
    ]) {
      expect(tester.getSize(b).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('result view shows counts and an error line with retry',
      (tester) async {
    var retried = 0;
    var done = 0;
    await tester.pumpWidget(_app(
      Scaffold(
        body: LmsImportResultView(
          summary: const LmsImportSummary(
            courses: 6,
            events: 30,
            classes: 21,
            materials: 42,
            errors: {'materials': 'HTTP 403'},
          ),
          onRetry: () => retried++,
          onDone: () => done++,
        ),
      ),
      theme: AppTheme.dark(),
    ));

    expect(find.text('Импорт завершён частично'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('9'), findsOneWidget); // deadlines = events - classes
    expect(find.text('21'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Не загрузилось'), findsOneWidget);
    expect(find.text('HTTP 403'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Повторить'));
    await tester.tap(find.widgetWithText(FilledButton, 'Готово'));
    expect(retried, 1);
    expect(done, 1);
  });

  testWidgets('result view without errors has no retry', (tester) async {
    await tester.pumpWidget(_app(
      Scaffold(
        body: LmsImportResultView(
          summary: const LmsImportSummary(
            courses: 1,
            events: 0,
            classes: 0,
            materials: 0,
            errors: {},
          ),
          onRetry: () {},
          onDone: () {},
        ),
      ),
    ));
    expect(find.text('Импорт завершён'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });
}
