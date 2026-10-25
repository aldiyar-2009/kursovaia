import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/theme/app_palette.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('EmptyState renders title, message and calls onAction',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_wrap(EmptyState(
      title: 'Заданий нет',
      message: 'Создайте задание',
      actionLabel: 'Новое задание',
      onAction: () => tapped++,
    )));

    expect(find.text('Заданий нет'), findsOneWidget);
    expect(find.text('Создайте задание'), findsOneWidget);
    await tester.tap(find.text('Новое задание'));
    expect(tapped, 1);
  });

  testWidgets('EmptyState without action shows no button', (tester) async {
    await tester.pumpWidget(_wrap(const EmptyState(title: 'T', message: 'M')));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('ListRow shows subtitle, trailing and handles taps',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(ListGroup(children: [
      ListRow(
        title: 'Группа',
        subtitle: 'Не выбрана',
        trailing: const ListRowChevron(),
        onTap: () => tapped = true,
      ),
      const ListRow(title: 'Второй'),
    ])));

    expect(find.text('Не выбрана'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    await tester.tap(find.text('Группа'));
    expect(tapped, isTrue);
  });

  testWidgets('SectionHeader and StatusLabel use palette colours',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const Column(children: [
        SectionHeader('Текущий семестр'),
        StatusLabel(text: 'Сдано', tone: StatusTone.success),
      ]),
      theme: AppTheme.dark(),
    ));

    expect(find.text('Текущий семестр'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Сдано'));
    expect(label.style!.color, AppPalette.dark.success);
  });

  test('themes expose the palette and keep elevation at zero', () {
    for (final (theme, palette) in [
      (AppTheme.light(), AppPalette.light),
      (AppTheme.dark(), AppPalette.dark),
    ]) {
      expect(theme.extension<AppPalette>(), palette);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.navigationBarTheme.elevation, 0);
      expect(theme.textTheme.headlineMedium!.fontSize, 28);
      expect(theme.textTheme.bodyMedium!.fontSize, 15);
    }
  });
}
