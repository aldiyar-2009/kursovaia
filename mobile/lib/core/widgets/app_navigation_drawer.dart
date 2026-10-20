import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_state.dart';
import 'package:studyplan/core/theme/app_colors.dart';

enum AppSection {
  timeline,
  schedule,
  deadlines,
  chat,
  campusMap,
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
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
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
                  _buildHeader(context),
                  const Divider(color: AppColors.border, height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      children: [
                        _buildMenuItem(
                          context,
                          section: AppSection.timeline,
                          icon: Icons.timer_outlined,
                          title: 'Таймлайн дня',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.schedule,
                          icon: Icons.calendar_month_outlined,
                          title: 'Полное расписание',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.deadlines,
                          icon: Icons.track_changes_outlined,
                          title: 'Дедлайны и задачи',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.chat,
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Чат группы',
                        ),
                        _buildMenuItem(
                          context,
                          section: AppSection.campusMap,
                          icon: Icons.map_outlined,
                          title: 'Карта кампуса',
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


  Widget _buildHeader(BuildContext context) {
    final isHeadman = userRole == 'headman';
    final roleText = isHeadman ? 'Староста' : 'Студент';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onSectionSelected(AppSection.profile);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isHeadman
                    ? AppColors.plate(AppColors.accent, 0.25)
                    : AppColors.plate(AppColors.accentCyan, 0.25),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isHeadman ? AppColors.accent : AppColors.accentCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Text(
              '$groupTitle • $semester семестр',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accentCyan,
              ),
            ),
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
  }) {
    final isSelected = currentSection == section;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? AppColors.plate(AppColors.accent, 0.15) : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? AppColors.accent : AppColors.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          onSectionSelected(section);
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.file_upload_outlined, size: 20, color: AppColors.textSecondary),
            title: const Text('Экспорт в JSON', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            onTap: () {
              Navigator.pop(context);
              onExportJson();
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.file_download_outlined, size: 20, color: AppColors.textSecondary),
            title: const Text('Импорт из JSON', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            onTap: () {
              Navigator.pop(context);
              onImportJson();
            },
          ),
          BlocBuilder<SyncBloc, SyncState>(
            builder: (context, state) {
              final isSyncing = state.status == SyncStatusState.syncing;
              return ListTile(
                dense: true,
                leading: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      )
                    : const Icon(Icons.sync_rounded, size: 20, color: AppColors.accentCyan),
                title: const Text('Синхронизировать', style: TextStyle(fontSize: 13, color: AppColors.accentCyan)),
                onTap: () {
                  context.read<SyncBloc>().add(SyncTriggered());
                },
              );
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout, size: 18, color: AppColors.danger),
            title: const Text('Выйти из аккаунта', style: TextStyle(fontSize: 13, color: AppColors.danger)),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}
