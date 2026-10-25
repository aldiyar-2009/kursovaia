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

class CampusMapScreen extends StatelessWidget {
  const CampusMapScreen({super.key});

  static const _center = LatLng(51.0907, 71.4184);

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
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(initialCenter: _center, initialZoom: 16.5),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.studyplan.app',
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
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: palette.border),
                ),
                child: Text(l10n.map_hint, style: context.text.bodySmall),
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
              color: palette.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(l10n.map_attribution, style: context.text.labelSmall),
          ),
        ),
      ],
    );
  }
}
