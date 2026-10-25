import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_palette.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/utils/due_format.dart';
import 'package:studyplan/core/widgets/ui/app_sheet.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/filter_chips.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

Widget _app(
  Widget home, {
  Locale locale = const Locale('ru'),
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  locale: locale,
  supportedLocales: kSupportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('ContentColumn', () {
    testWidgets('constrains content to 720 px at 1280 px width', (
      tester,
    ) async {
      _setSize(tester, const Size(1280, 800));
      const key = Key('content');
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: ContentColumn(child: SizedBox(key: key, height: 10)),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(key));
      expect(rect.width, kContentMaxWidth);
      expect(rect.left, (1280 - 720) / 2);
      expect(contentInset(1280), rect.left);
    });

    testWidgets('keeps a 16 px gutter on phones', (tester) async {
      _setSize(tester, const Size(400, 800));
      const key = Key('content');
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: ContentColumn(child: SizedBox(key: key, height: 10)),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, 16);
      expect(rect.width, 400 - 32);
    });

    testWidgets('ContentAppBar title starts at the content column edge', (
      tester,
    ) async {
      _setSize(tester, const Size(1280, 800));
      const key = Key('content');
      await tester.pumpWidget(
        _app(
          const Scaffold(
            appBar: ContentAppBar(title: Text('Задания')),
            body: ContentColumn(child: SizedBox(key: key, height: 10)),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Задания')).dx,
        tester.getTopLeft(find.byKey(key)).dx,
      );
    });
  });

  group('showAppSheet', () {
    testWidgets('shows title, handle and primary action; closes on X', (
      tester,
    ) async {
      _setSize(tester, const Size(400, 800));
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  title: 'Новое задание',
                  builder: (_) => const Text('Тело'),
                  primaryAction: FilledButton(
                    onPressed: () {},
                    child: const Text('Сохранить'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Новое задание'), findsOneWidget);
      expect(find.text('Тело'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-sheet-handle')), findsOneWidget);
      final button = tester.getSize(find.byType(FilledButton));
      expect(button.height, greaterThanOrEqualTo(kPrimaryButtonHeight));
      expect(button.width, 400 - 32);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Новое задание'), findsNothing);
    });

    testWidgets('is at most 640 px wide on wide screens', (tester) async {
      _setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  title: 'T',
                  builder: (_) => const SizedBox(
                    key: Key('body'),
                    width: double.infinity,
                    height: 20,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('body'))).width,
        kSheetMaxWidth - 32,
      );
    });
  });

  testWidgets('SegmentedToggle reports selection changes', (tester) async {
    var value = 'day';
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SegmentedToggle<String>(
              segments: const [('day', 'День'), ('week', 'Неделя')],
              value: value,
              expand: true,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );

    FontWeight? weight(String label) =>
        tester.widget<Text>(find.text(label)).style!.fontWeight;
    expect(weight('День'), FontWeight.w600);
    expect(weight('Неделя'), FontWeight.w500);

    await tester.tap(find.text('Неделя'));
    await tester.pump();
    expect(value, 'week');
    expect(weight('Неделя'), FontWeight.w600);
    expect(weight('День'), FontWeight.w500);
  });

  testWidgets('SegmentedToggle selected segment differs from track in dark', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SegmentedToggle<int>(
            segments: const [(0, 'A'), (1, 'B')],
            value: 0,
            onChanged: (_) {},
          ),
        ),
        theme: AppTheme.dark(),
      ),
    );
    final box = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('A'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final fill = (box.decoration! as BoxDecoration).color;
    expect(fill, isNot(AppPalette.dark.surfaceMuted));
    expect(fill, isNot(AppPalette.dark.surface));
  });

  testWidgets('FilterChipsRow fills the selected chip and reports taps', (
    tester,
  ) async {
    int? picked;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: FilterChipsRow<int>(
            items: const [(0, 'Все'), (1, 'Мои'), (2, 'Группа')],
            value: 0,
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.text('Все')).dx, greaterThanOrEqualTo(16));
    expect(
      tester.getSize(find.byType(AppFilterChip).first).height,
      kFilterChipHeight,
    );
    final selected = tester.widget<Text>(find.text('Все'));
    expect(selected.style!.color, AppPalette.light.onPrimary);

    await tester.tap(find.text('Мои'));
    expect(picked, 1);
  });

  group('formatDue', () {
    final now = DateTime(2026, 10, 26, 10); // Monday

    Future<String> format(
      WidgetTester tester,
      DateTime due, {
      Locale locale = const Locale('ru'),
    }) async {
      late String result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              result = formatDue(context, due, now: now);
              return const SizedBox();
            },
          ),
          locale: locale,
        ),
      );
      return result;
    }

    testWidgets('ru', (tester) async {
      expect(
        await format(tester, DateTime(2026, 10, 26, 20)),
        'Сегодня, 20:00',
      );
      expect(await format(tester, DateTime(2026, 10, 27, 18)), 'Завтра, 18:00');
      expect(await format(tester, DateTime(2026, 10, 25, 9)), 'Вчера, 09:00');
      expect(await format(tester, DateTime(2026, 10, 29, 12)), 'чт, 29 окт.');
      expect(await format(tester, DateTime(2026, 12, 15)), '15 дек.');
      expect(await format(tester, DateTime(2027, 1, 10)), contains('2027'));
    });

    testWidgets('en', (tester) async {
      const en = Locale('en');
      expect(
        await format(tester, DateTime(2026, 10, 26, 20), locale: en),
        'Today, 20:00',
      );
      expect(
        await format(tester, DateTime(2026, 10, 27, 18), locale: en),
        'Tomorrow, 18:00',
      );
      expect(
        await format(tester, DateTime(2026, 10, 29, 12), locale: en),
        'Thu, Oct 29',
      );
      expect(
        await format(tester, DateTime(2026, 12, 15), locale: en),
        'Dec 15',
      );
    });

    testWidgets('kk uses Kazakh relative days', (tester) async {
      expect(
        await format(
          tester,
          DateTime(2026, 10, 27, 8),
          locale: const Locale('kk'),
        ),
        'Ертең, 08:00',
      );
    });
  });

  testWidgets('FilledButton is at least 44 px tall on desktop density', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: FilledButton(onPressed: () {}, child: const Text('OK')),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(44),
      );
      expect(AppTheme.light().visualDensity, VisualDensity.standard);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
