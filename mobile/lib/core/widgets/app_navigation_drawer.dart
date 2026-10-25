import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_state.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';
import 'package:studyplan/features/lms/presentation/widgets/lms_modal.dart';

enum AppSection {
  portal,
  timeline,
  schedule,
  deadlines,
  grades,
  simulator,
  retakes,
  scholarship,
  calendar,
  files,
  campusMap,
  reminders,
  chat,
  admin,
  profile,
}

class AppNavigationDrawer extends StatelessWidget {
  final AppSection currentSection;
  final ValueChanged<AppSection> onSectionSelected;
  final String userName;
  final String userRole;
  final String groupTitle;
  final int semester;
  final VoidCallback onExportJson;
  final VoidCallback onImportJson;
  final VoidCallback onLogout;

  const AppNavigationDrawer({
    super.key,
    required this.currentSection,
    required this.onSectionSelected,
    required this.userName,
    required this.userRole,
    required this.groupTitle,
    required this.semester,
    required this.onExportJson,
    required this.onImportJson,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final dataService = AituDataService();

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.95),
            border: const Border(
              right: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, dataService),
                  const Divider(color: AppColors.border, height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      children: [
                        _buildCategoryHeader('УЧЕБНЫЙ ПРОЦЕСС'),
                        _buildMenuItem(
                          context,
                          section: AppSection.portal,
                          icon: Icons.home_rounded,
                          title: 'Главная (Портал)',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.schedule,
                          icon: Icons.calendar_month_outlined,
                          title: 'Расписание пар',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.timeline,
                          icon: Icons.view_timeline_outlined,
                          title: 'Таймлайн дня',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.deadlines,
                          icon: Icons.assignment_outlined,
                          title: 'Домашние задания',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.grades,
                          icon: Icons.insights_rounded,
                          title: 'Оценки',
                          badge: '82.6',
                          badgeColor: AppColors.accentCyan,
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.retakes,
                          icon: Icons.assignment_late_outlined,
                          title: 'Отработки',
                          badge: '1',
                          badgeColor: AppColors.warning,
                        ),

                        const SizedBox(height: 12),
                        _buildCategoryHeader('ИНСТРУМЕНТЫ И РАСЧЁТЫ'),
                        _buildMenuItem(
                          context,
                          section: AppSection.simulator,
                          icon: Icons.science_outlined,
                          title: 'Симулятор («А что, если?»)',
                          badge: 'NEW',
                          badgeColor: AppColors.accent,
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.scholarship,
                          icon: Icons.military_tech_outlined,
                          title: 'Повышка (Стипендия)',
                          badge: '90+',
                          badgeColor: AppColors.success,
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.reminders,
                          icon: Icons.notifications_active_outlined,
                          title: 'Напоминания & .ICS',
                        ),

                        const SizedBox(height: 12),
                        _buildCategoryHeader('МАТЕРИАЛЫ И КАМПУС'),
                        _buildMenuItem(
                          context,
                          section: AppSection.calendar,
                          icon: Icons.event_note_rounded,
                          title: 'Календарь 2026–2027',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.files,
                          icon: Icons.folder_shared_rounded,
                          title: 'Файлы и материалы',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.campusMap,
                          icon: Icons.map_outlined,
                          title: 'Карта AITU',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.chat,
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Чат группы',
                        ),

                        const SizedBox(height: 12),
                        _buildCategoryHeader('УПРАВЛЕНИЕ'),
                        _buildActionItem(
                          context,
                          icon: Icons.cloud_sync_rounded,
                          title: 'LMS AITU интеграция',
                          iconColor: AppColors.accentCyan,
                          onTap: () {
                            Navigator.pop(context);
                            LmsModal.show(context);
                          },
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.admin,
                          icon: Icons.shield_outlined,
                          title: 'Администрирование',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.profile,
                          icon: Icons.person_outline_rounded,
                          title: 'Мой профиль',
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AituDataService dataService) {
    final isHeadman = userRole == 'headman';
    final roleText = isHeadman ? 'Староста группы' : 'Студент';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onSectionSelected(AppSection.profile);
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              AppColors.plate(AppColors.accent, 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.school_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AITU',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 0.5),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'UNIVERSITY',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentCyan, letterSpacing: 1.0),
                        ),
                      ],
                    ),
                    Text(
                      'Portal & Offline Sync',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isHeadman
                      ? AppColors.plate(AppColors.accent, 0.3)
                      : AppColors.plate(AppColors.accentCyan, 0.3),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isHeadman ? AppColors.accent : AppColors.accentCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        roleText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    dataService.currentGroup,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '$semester семестр',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.plate(AppColors.success, 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 10, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'LMS AITU',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required AppSection section,
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = currentSection == section;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? AppColors.plate(AppColors.accent, 0.18) : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.accentCyan : AppColors.textSecondary,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.accent).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: (badgeColor ?? AppColors.accent).withValues(alpha: 0.5)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeColor ?? AppColors.accent,
                  ),
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context);
          onSectionSelected(section);
        },
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '2026 — 2027 · UTC+5 · AITU',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onExportJson();
                  },
                  icon: const Icon(Icons.upload_rounded, size: 14),
                  label: const Text('Экспорт', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onImportJson();
                  },
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Импорт', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BlocBuilder<SyncBloc, SyncState>(
            builder: (context, state) {
              final isSyncing = state.status == SyncStatusState.syncing;
              return InkWell(
                onTap: () => context.read<SyncBloc>().add(SyncTriggered()),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8),
                  child: Row(
                    children: [
                      isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                            )
                          : const Icon(Icons.sync_rounded, size: 18, color: AppColors.accentCyan),
                      const SizedBox(width: 10),
                      const Text('Синхронизировать офлайн-базу', style: TextStyle(fontSize: 12, color: AppColors.accentCyan)),
                    ],
                  ),
                ),
              );
            },
          ),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('Выйти из аккаунта', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
