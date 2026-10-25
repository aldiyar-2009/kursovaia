import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Reference points of the AITU campus (EXPO, Astana).
enum _CampusPlace {
  main(LatLng(51.0907, 71.4184)),
  labs(LatLng(51.0913, 71.4192)),
  library(LatLng(51.0902, 71.4176)),
  sport(LatLng(51.0898, 71.4195));

  const _CampusPlace(this.point);
  final LatLng point;

  String title(AppLocalizations l10n) => switch (this) {
        main => l10n.map_mainTitle,
        labs => l10n.map_labsTitle,
        library => l10n.map_libraryTitle,
        sport => l10n.map_sportTitle,
      };

  String description(AppLocalizations l10n) => switch (this) {
        main => l10n.map_mainDesc,
        labs => l10n.map_labsDesc,
        library => l10n.map_libraryDesc,
        sport => l10n.map_sportDesc,
      };
}

/// CARTO basemaps: free with attribution, separate light and dark styles.
/// (tile.openstreetmap.org rejects third-party apps with "403 Access blocked".)
const cartoLightUrl =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
const cartoDarkUrl =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

/// Required by the OSM (ODbL) and CARTO basemap licences; not translated.
const mapAttribution = '© OpenStreetMap contributors © CARTO';

/// Android applicationId, sent in the tile User-Agent on native platforms.
const _userAgentPackageName = 'com.studyplan.studyplan';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key, this.tileProvider});

  /// Overrides tile loading (tests); defaults to [NetworkTileProvider].
  @visibleForTesting
  final TileProvider? tileProvider;

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  static const _center = LatLng(51.0907, 71.4184);

  /// True after a tile failed to load (offline / blocked host) and until a
  /// tile loads successfully again.
  bool _tilesFailed = false;

  void _setTilesFailed(bool value) {
    if (_tilesFailed == value) return;
    // Tile callbacks may fire during build/layout; defer the rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tilesFailed != value) {
        setState(() => _tilesFailed = value);
      }
    });
  }

  void _showPlace(BuildContext context, _CampusPlace place) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.title(l10n), style: ctx.text.titleMedium),
              const SizedBox(height: 8),
              Text(
                place.description(l10n),
                style: ctx.text.bodyMedium!
                    .copyWith(color: ctx.palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 16.5,
            maxZoom: 20,
            backgroundColor: palette.surfaceMuted,
          ),
          children: [
            TileLayer(
              // Keyed by style so switching theme reloads the tiles.
              key: ValueKey(isDark),
              urlTemplate: isDark ? cartoDarkUrl : cartoLightUrl,
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
              maxNativeZoom: 20,
              userAgentPackageName: _userAgentPackageName,
              tileProvider: widget.tileProvider,
              errorTileCallback: (_, _, _) => _setTilesFailed(true),
              tileBuilder: (context, tileWidget, tile) {
                if (_tilesFailed && tile.readyToDisplay && !tile.loadError) {
                  _setTilesFailed(false);
                }
                return tileWidget;
              },
            ),
            MarkerLayer(
              markers: [
                for (final place in _CampusPlace.values)
                  Marker(
                    point: place.point,
                    width: 44,
                    height: 44,
                    child: Semantics(
                      button: true,
                      label: place.title(l10n),
                      child: GestureDetector(
                        onTap: () => _showPlace(context, place),
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: palette.surface, width: 2),
                            ),
                            child: Icon(
                              Icons.school_outlined,
                              color: palette.onPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(l10n.map_hint, style: context.text.bodySmall),
                  ),
                  if (_tilesFailed) ...[
                    const SizedBox(height: 8),
                    _OfflineNote(text: l10n.map_offlineNote),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              mapAttribution,
              style: context.text.labelSmall!
                  .copyWith(color: palette.textSecondary, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 16, color: palette.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall!
                  .copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
