import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

void main() {
  testWidgets('MainShellScreen renders without RenderErrorBox', (tester) async {
    final db = AppDatabase();
    final apiClient = ApiClient();
    final user = {
      'id': 'test-user-id',
      'name': 'Алина Смирнова',
      'role': 'headman',
    };
    final group = {
      'id': 'test-group-id',
      'title': 'ИВТ-21',
      'semester': 3,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScreen(
          db: db,
          apiClient: apiClient,
          user: user,
          group: group,
          onLogout: () {},
        ),
      ),
    );

    // Pump frames to let streams and initial layout resolve
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
