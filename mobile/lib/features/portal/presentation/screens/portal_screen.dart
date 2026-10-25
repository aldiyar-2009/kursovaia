import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/widgets/app_navigation_drawer.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';
import 'package:studyplan/features/lms/presentation/widgets/lms_modal.dart';

class PortalScreen extends StatefulWidget {
  final ValueChanged<AppSection> onNavigate;
  final String userName;
  final String userRole;

  const PortalScreen({
    super.key,
    required this.onNavigate,
    required this.userName,
    required this.userRole,
  });

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  final _dataService = AituDataService();

  @override
  void initState() {
    super.initState();
    _dataService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _dataService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      children: [
        _buildHeroBanner(),
        const SizedBox(height: 18),
        _buildMetricsGrid(),
        const SizedBox(height: 22),
        _buildTodaySchedulePreview(),
        const SizedBox(height: 22),
        _buildQuickModulesSection(),
      ],
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.elevated,
            AppColors.plate(AppColors.accent, 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.plate(AppColors.accentCyan, 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.plate(AppColors.accentCyan, 0.3)),
                ),
                child: const Text(
                  'ВАШ ПОРТАЛ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.accentCyan,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Группа: ${_dataService.currentGroup}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Добро пожаловать, ${widget.userName}!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Учёба в Astana IT University — в одном пространстве',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => LmsModal.show(context),
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  _dataService.isLmsConnected ? 'LMS AITU подключен' : 'Подключить LMS AITU',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate(AppSection.simulator),
                icon: const Icon(Icons.science_outlined, size: 16, color: AppColors.accentCyan),
                label: const Text('Симулятор баллов', style: TextStyle(color: AppColors.accentCyan)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.accentCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final avg = _dataService.overallAverage;
    final excellent = _dataService.excellentCount;
    final retakes = _dataService.retakesSubjectsCount;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _buildMetricCard(
          title: 'Общий средний',
          value: '$avg',
          unit: '/ 100',
          subtitle: 'GPA: 3.33 · B+',
          color: AppColors.accentCyan,
          icon: Icons.trending_up_rounded,
          onTap: () => widget.onNavigate(AppSection.grades),
        ),
        _buildMetricCard(
          title: 'На «Отлично»',
          value: '$excellent',
          unit: '/ ${_dataService.subjects.length}',
          subtitle: '90+ баллов',
          color: AppColors.success,
          icon: Icons.star_rounded,
          onTap: () => widget.onNavigate(AppSection.grades),
        ),
        _buildMetricCard(
          title: 'Есть отработки',
          value: '$retakes',
          unit: ' предм.',
          subtitle: 'Химия (45.7)',
          color: retakes > 0 ? AppColors.warning : AppColors.success,
          icon: Icons.warning_amber_rounded,
          onTap: () => widget.onNavigate(AppSection.retakes),
        ),
        _buildMetricCard(
          title: 'Повышенная стипендия',
          value: '43 574',
          unit: ' ₸',
          subtitle: 'Цель: 50 110 ₸ (+15%)',
          color: AppColors.accent,
          icon: Icons.military_tech_outlined,
          onTap: () => widget.onNavigate(AppSection.scholarship),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                ),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySchedulePreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 18, color: AppColors.accentCyan),
                  SizedBox(width: 8),
                  Text(
                    'Пары на сегодня',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => widget.onNavigate(AppSection.schedule),
                child: const Text('Все расписание →', style: TextStyle(fontSize: 12, color: AppColors.accentCyan)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLessonItem(
            time: '08:30 — 09:50',
            title: 'Алгоритмы и структуры данных',
            teacher: 'Амиров Т.С.',
            room: 'Ауд. С1.2.245',
            type: 'Лекция',
            status: 'Завершена',
            isCurrent: false,
          ),
          const SizedBox(height: 8),
          _buildLessonItem(
            time: '10:05 — 11:25',
            title: 'Базы данных и SQL',
            teacher: 'Жумадилов А.К.',
            room: 'Mac Lab C1.3',
            type: 'Лабораторная',
            status: 'Сейчас идёт',
            isCurrent: true,
          ),
          const SizedBox(height: 8),
          _buildLessonItem(
            time: '11:40 — 13:00',
            title: 'Основы веб-разработки',
            teacher: 'Сейтжанов М.А.',
            room: 'Ауд. С1.2.210',
            type: 'Практика',
            status: 'Следующая',
            isCurrent: false,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonItem({
    required String time,
    required String title,
    required String teacher,
    required String room,
    required String type,
    required String status,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.plate(AppColors.accentCyan, 0.12) : AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.accentCyan : AppColors.border,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.accentCyan : AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? AppColors.accentCyan : AppColors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.accentCyan : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '$teacher • $room • $type',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickModulesSection() {
    final modules = [
      {'section': AppSection.grades, 'title': 'Оценки', 'icon': Icons.insights_rounded, 'desc': 'Журнал LMS AITU'},
      {'section': AppSection.simulator, 'title': 'Симулятор', 'icon': Icons.science_outlined, 'desc': 'Прогноз «А что, если?»'},
      {'section': AppSection.retakes, 'title': 'Отработки', 'icon': Icons.assignment_late_outlined, 'desc': 'Ликвидация хвостов'},
      {'section': AppSection.scholarship, 'title': 'Повышка', 'icon': Icons.military_tech_outlined, 'desc': 'Расчет стипендии'},
      {'section': AppSection.calendar, 'title': 'Календарь', 'icon': Icons.calendar_month_outlined, 'desc': 'Сессии и каникулы'},
      {'section': AppSection.files, 'title': 'Файлы', 'icon': Icons.folder_shared_rounded, 'desc': 'Силлабусы и лекции'},
      {'section': AppSection.campusMap, 'title': 'Карта AITU', 'icon': Icons.map_outlined, 'desc': 'Аудитории и этажи'},
      {'section': AppSection.reminders, 'title': 'Напоминания', 'icon': Icons.notifications_active_outlined, 'desc': 'Экспорт .ICS'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Все сервисы университета AITU',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemCount: modules.length,
          itemBuilder: (context, idx) {
            final m = modules[idx];
            return InkWell(
              onTap: () => widget.onNavigate(m['section'] as AppSection),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.plate(AppColors.accent, 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(m['icon'] as IconData, size: 18, color: AppColors.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m['title'] as String,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            m['desc'] as String,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
