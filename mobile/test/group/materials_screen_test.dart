import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/features/materials/presentation/screens/materials_screen.dart';

import 'group_test_utils.dart';

Map<String, dynamic> _material({
  required String id,
  required String title,
  required String subject,
  String uploaderId = 'u2',
}) =>
    {
      'id': id,
      'group_id': 'g1',
      'uploader_id': uploaderId,
      'uploader_name': 'Данияр Ахметов',
      'subject_code': subject,
      'subject_title': subject,
      'title': title,
      'file_name': '$title.pdf',
      'file_path': '00000000-0000-0000-0000-00000000000$id.pdf',
      'file_size': 2048,
      'file_type': 'pdf',
      'created_at': 1000,
    };

void main() {
  testWidgets('LMS tab lists a material from drift and opens its URL',
      (tester) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.lmsMaterials).insert(LmsMaterialsCompanion.insert(
          id: 'm1',
          userId: 'u1',
          courseTitle: const Value('Linear Algebra'),
          sectionTitle: const Value('Week 1'),
          title: 'Lecture 1 slides',
          materialType: const Value('file'),
          url: const Value('https://lms.astanait.edu.kz/mod/resource/1'),
          updatedAt: BigInt.from(1),
        ));
    final api = fakeApi({'GET /materials': (_) => {'materials': <Object>[]}});
    Uri? opened;

    await tester.pumpWidget(wrapApp(MaterialsScreen(
      db: db,
      apiClient: api,
      userId: 'u1',
      groupId: 'g1',
      initialTab: 1,
      openUrl: (url) async {
        opened = url;
        return true;
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Linear Algebra'), findsOneWidget);
    expect(find.text('Lecture 1 slides'), findsOneWidget);
    expect(find.text('Файл · Week 1'), findsOneWidget);

    await tester.tap(find.text('Lecture 1 slides'));
    await tester.pump();
    expect(opened.toString(), 'https://lms.astanait.edu.kz/mod/resource/1');

    await disposeWithDb(tester, db);
  });

  testWidgets('group tab shows retry on API error, then the list',
      (tester) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    var fail = true;
    final api = fakeApi({
      'GET /materials': (o) {
        if (fail) throw offline(o);
        return {
          'materials': [
            _material(id: '1', title: 'Конспект лекции 3', subject: 'Физика'),
            _material(
              id: '2',
              title: 'Шпаргалка к модулю',
              subject: 'История',
              uploaderId: 'u1',
            ),
          ],
        };
      },
    });

    await tester.pumpWidget(wrapApp(MaterialsScreen(
      db: db,
      apiClient: api,
      userId: 'u1',
      groupId: 'g1',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Конспект лекции 3'), findsOneWidget);
    expect(find.text('Шпаргалка к модулю'), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);

    // Subject filter.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Физика'));
    await tester.pumpAndSettle();
    expect(find.text('Конспект лекции 3'), findsOneWidget);
    expect(find.text('Шпаргалка к модулю'), findsNothing);

    await disposeWithDb(tester, db);
  });

  testWidgets('cached list is shown offline with a quiet retry notice',
      (tester) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    var fail = false;
    final api = fakeApi({
      'GET /materials': (o) {
        if (fail) throw offline(o);
        return {
          'materials': [
            _material(id: '1', title: 'Конспект лекции 3', subject: 'Физика'),
          ],
        };
      },
    });
    Widget screen() => wrapApp(MaterialsScreen(
          key: UniqueKey(),
          db: db,
          apiClient: api,
          userId: 'u1',
          groupId: 'g1',
        ));

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Конспект лекции 3'), findsOneWidget);

    fail = true;
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Конспект лекции 3'), findsOneWidget);
    expect(find.text('Нет соединения. Показан сохранённый список.'),
        findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await disposeWithDb(tester, db);
  });

  testWidgets('group tab without a group offers join and create',
      (tester) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(wrapApp(MaterialsScreen(
      db: db,
      apiClient: fakeApi({}),
      userId: 'u1',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Материалы доступны в группе'), findsOneWidget);
    expect(find.text('Вступить по коду'), findsOneWidget);
    expect(find.text('Создать группу'), findsOneWidget);

    await disposeWithDb(tester, db);
  });
}
