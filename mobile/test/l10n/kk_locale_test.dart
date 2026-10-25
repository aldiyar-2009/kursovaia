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
  testWidgets('Kazakh locale shows Kazakh strings', (tester) async {
    final ru = await _load(tester, const Locale('ru'));
    final kk = await _load(tester, const Locale('kk'));

    expect(kk.localeName, 'kk');
    expect(find.text(kk.nav_home), findsOneWidget);

    final navPairs = <(String, String)>[
      (kk.nav_home, ru.nav_home),
      (kk.nav_schedule, ru.nav_schedule),
      (kk.nav_tasks, ru.nav_tasks),
      (kk.nav_grades, ru.nav_grades),
      (kk.nav_more, ru.nav_more),
      (kk.nav_group, ru.nav_group),
      (kk.nav_profileSettings, ru.nav_profileSettings),
    ];
    for (final (kkLabel, ruLabel) in navPairs) {
      expect(kkLabel.trim(), isNotEmpty);
      expect(kkLabel, isNot(ruLabel));
    }

    // Kazakh uses the singular after a numeral for every count.
    expect(kk.grades_credits(1), '1 кредит');
    expect(kk.grades_credits(5), '5 кредит');
    expect(kk.group_membersCount(1), '1 мүше');
    expect(kk.group_membersCount(5), '5 мүше');
    expect(kk.grades_credits(5), isNot(ru.grades_credits(5)));
  });
}
