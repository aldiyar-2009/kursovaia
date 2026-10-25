import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/campus_map/presentation/screens/campus_map_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Every tile is an undecodable image, i.e. behaves like a failed download.
class _FailingTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(Uint8List(0));
}

/// Never touches the network: tiles stay pending.
class _SilentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const _PendingImage();
}

class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage();

  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

Future<void> _pump(
  WidgetTester tester, {
  required ThemeData theme,
  TileProvider? tileProvider,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en'), Locale('kk')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: CampusMapScreen(tileProvider: tileProvider ?? _SilentTileProvider()),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('light theme uses CARTO light_all tiles', (tester) async {
    await _pump(tester, theme: AppTheme.light());
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, contains('basemaps.cartocdn.com'));
    expect(layer.urlTemplate, contains('light_all'));
    expect(layer.urlTemplate, isNot(contains('openstreetmap.org')));
    expect(layer.subdomains, ['a', 'b', 'c', 'd']);
  });

  testWidgets('dark theme uses CARTO dark_all tiles', (tester) async {
    await _pump(tester, theme: AppTheme.dark());
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, contains('dark_all'));
  });

  testWidgets('shows OSM and CARTO attribution and all four markers',
      (tester) async {
    await _pump(tester, theme: AppTheme.light());
    expect(find.text('© OpenStreetMap contributors © CARTO'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsNWidgets(4));
    expect(find.text('Карта недоступна без интернета'), findsNothing);
  });

  testWidgets('shows offline note when tiles fail, markers still render',
      (tester) async {
    await _pump(
      tester,
      theme: AppTheme.light(),
      tileProvider: _FailingTileProvider(),
    );
    // Let the image decoder reject the empty bytes.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Карта недоступна без интернета'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsNWidgets(4));
  });
}
