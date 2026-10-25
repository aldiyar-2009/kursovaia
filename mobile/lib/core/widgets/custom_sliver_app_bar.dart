import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_state.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';
import 'package:studyplan/features/lms/presentation/widgets/lms_modal.dart';

class CustomSliverAppBar extends StatelessWidget {
  final DateTime selectedDate;
  final String? sectionTitle;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;

  const CustomSliverAppBar({
    super.key,
    required this.selectedDate,
    this.sectionTitle,
    this.onSearchTap,
    this.onProfileTap,
  });

  void _showGroupPicker(BuildContext context) {
    final dataService = AituDataService();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.groups_rounded, color: AppColors.accentCyan, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Выберите учебную группу',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Расписание, пары и предметы автоматически обновляются под выбранную группу AITU.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: AituDataService.universityGroups.map((cg) {
                    final courseName = cg['course'] as String;
                    final groups = cg['groups'] as List<String>;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            courseName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: groups.map((g) {
                            final isCur = dataService.currentGroup == g;
                            return ChoiceChip(
                              label: Text(g),
                              selected: isCur,
                              onSelected: (_) {
                                dataService.setGroup(g);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surface,
                                    content: Text('Выбрана группа $g ($courseName)'),
                                  ),
                                );
                              },
                              selectedColor: AppColors.accentCyan,
                              backgroundColor: AppColors.elevated,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isCur ? FontWeight.w800 : FontWeight.w500,
                                color: isCur ? Colors.black : AppColors.textPrimary,
                              ),
                              side: BorderSide(color: isCur ? AppColors.accentCyan : AppColors.border),
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = AituDataService();

    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: AppColors.border,
          height: 1.0,
        ),
      ),
      leading: IconButton(
        icon: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 13,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.accentCyan,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 18,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
        tooltip: 'Меню',
      ),
      title: AnimatedBuilder(
        animation: dataService,
        builder: (context, _) => InkWell(
          onTap: () => _showGroupPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sectionTitle ?? 'Astana IT University',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Группа: ${dataService.currentGroup}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentCyan,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.accentCyan),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => LmsModal.show(context),
          icon: const Icon(Icons.cloud_done_rounded, size: 20, color: AppColors.accentCyan),
          tooltip: 'LMS AITU',
        ),
        BlocBuilder<SyncBloc, SyncState>(
          builder: (context, state) {
            Color statusColor;
            String tooltip;

            switch (state.status) {
              case SyncStatusState.synced:
                statusColor = AppColors.success;
                tooltip = 'Офлайн база синхронизирована';
                break;
              case SyncStatusState.syncing:
                statusColor = AppColors.accent;
                tooltip = 'Синхронизация...';
                break;
              case SyncStatusState.offlinePending:
                statusColor = AppColors.warning;
                tooltip = 'Локальные изменения (${state.pendingCount})';
                break;
              case SyncStatusState.error:
                statusColor = AppColors.danger;
                tooltip = 'Офлайн-режим';
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Center(
                child: Tooltip(
                  message: tooltip,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      context.read<SyncBloc>().add(SyncTriggered());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (onProfileTap != null)
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 22, color: AppColors.textPrimary),
            onPressed: onProfileTap,
            tooltip: 'Профиль',
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}
