import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:studyplan/core/theme/app_colors.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  // Astana IT University (AITU) coordinates in EXPO, Astana (51.0907, 71.4184)
  final LatLng _aituCenter = const LatLng(51.0907, 71.4184);

  final List<({String title, String desc, LatLng point, Color color})> _aituLocations = [
    (
      title: 'AITU Главный кампус (C1)',
      desc: 'Ректорат, Актовый зал, Ауд. C1.1.200 - C1.3.350',
      point: const LatLng(51.0907, 71.4184),
      color: AppColors.accent,
    ),
    (
      title: 'Блок C2 (Лаборатории)',
      desc: 'Лаборатории Cisco, Huawei ICT, Ауд. C2.2.100 - C2.3.250',
      point: const LatLng(51.0913, 71.4192),
      color: AppColors.accentCyan,
    ),
    (
      title: 'AITU Библиотека & Coworking',
      desc: 'Зона тихой учебы, Open Space, Meeting Rooms',
      point: const LatLng(51.0902, 71.4176),
      color: AppColors.warning,
    ),
    (
      title: 'Спорткомплекс & Food Court',
      desc: 'Спортивные секции, Столовая AITU, Coffee Point',
      point: const LatLng(51.0898, 71.4195),
      color: AppColors.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _aituCenter,
            initialZoom: 16.5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.studyplan.app',
            ),
            MarkerLayer(
              markers: _aituLocations.map((b) {
                return Marker(
                  point: b.point,
                  width: 46,
                  height: 46,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: AppColors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(backgroundColor: b.color, radius: 6),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      b.title,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(b.desc, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: b.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: b.color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: AppColors.accentCyan),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Astana IT University (AITU, Expo) — нажмите на маркер для просмотра',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
