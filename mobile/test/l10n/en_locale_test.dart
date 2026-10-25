import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

Future<AppLocalizations> _load(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(builder: (context) {
      l10n = AppLocalizations.of(context);
      return Text(l10n.nav_home);
    }),
  ));
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  testWidgets('English locale shows English strings', (tester) async {
    final en = await _load(tester, const Locale('en'));
    expect(find.text('Home'), findsOneWidget);
    expect(en.nav_schedule, 'Schedule');
    expect(en.nav_tasks, 'Tasks');
    expect(en.nav_grades, 'Grades');
    expect(en.nav_more, 'More');
    expect(en.grades_importLms, 'Import from LMS');
    expect(en.grades_credits(1), '1 credit');
    expect(en.grades_credits(5), '5 credits');
    expect(en.profile_remindersOn(0), startsWith('No upcoming deadlines'));

    final ru = await _load(tester, const Locale('ru'));
    expect(find.text('Главная'), findsOneWidget);
    expect(ru.nav_home, isNot(en.nav_home));
    expect(ru.nav_schedule, isNot(en.nav_schedule));
    expect(ru.nav_grades, isNot(en.nav_grades));
  });
}
