import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_palette.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';
import 'package:studyplan/features/more/presentation/screens/more_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

import '../core/fake_sync_repository.dart';

/// Pumps the shell (it provides the SyncBloc the More screen needs) and
/// opens the «Ещё» tab.
Future<AppDatabase> _pumpMore(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ru'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MainShellScreen(
        db: db,
        apiClient: ApiClient(),
        settings: AppSettings(),
        user: const {'id': 'u1', 'name': 'Test User', 'email': 'u@example.com'},
        onLogout: () {},
        // The shell syncs on start; a fake repository finishes at once.
        syncRepository: FakeSyncRepository(db),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Ещё').first);
  await tester.pump();
  return db;
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}

void main() {
  testWidgets('content column is at most 720 px wide at 1280 px', (
    tester,
  ) async {
    final db = await _pumpMore(tester, const Size(1280, 900));

    final groups = find.descendant(
      of: find.byType(MoreScreen),
      matching: find.byType(ListGroup),
    );
    expect(groups, findsWidgets);
    for (final element in groups.evaluate()) {
      final box = element.renderObject! as RenderBox;
      expect(box.size.width, lessThanOrEqualTo(720));
    }

    // The profile row's chevron stays next to the column, not at the
    // far edge of the window.
    final screenRight = tester.getTopRight(find.byType(MoreScreen)).dx;
    final chevronRight = tester
        .getTopRight(find.byType(ListRowChevron).first)
        .dx;
    expect(screenRight - chevronRight, greaterThan(100));
    expect(tester.takeException(), isNull);
    await _dispose(tester, db);
  });

  testWidgets('sync action is a quiet secondary text button', (tester) async {
    final db = await _pumpMore(tester, const Size(400, 800));

    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey('more_sync_now')),
    );
    final context = tester.element(find.byType(MoreScreen));
    final palette = Theme.of(context).extension<AppPalette>()!;
    expect(
      button.style!.foregroundColor!.resolve(<WidgetState>{}),
      palette.textSecondary,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('more_sync_now'))).height,
      greaterThanOrEqualTo(44),
    );
    await _dispose(tester, db);
  });
}
