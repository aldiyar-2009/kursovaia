import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_state.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/utils/date_util.dart';

class CustomSliverAppBar extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;

  const CustomSliverAppBar({
    super.key,
    required this.selectedDate,
    this.onSearchTap,
    this.onProfileTap,
  });


  @override
  Widget build(BuildContext context) {
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
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateUtil.formatHeaderDate(selectedDate),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateUtil.weekName(selectedDate),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.accentCyan,
            ),
          ),
        ],
      ),
      actions: [
        BlocBuilder<SyncBloc, SyncState>(
          builder: (context, state) {
            Color statusColor;
            String tooltip;

            switch (state.status) {
              case SyncStatusState.synced:
                statusColor = AppColors.success;
                tooltip = 'Синхронизировано с сервером';
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
                tooltip = 'Ошибка сети';
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
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
        if (onSearchTap != null)
          IconButton(
            icon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
            onPressed: onSearchTap,
            tooltip: 'Поиск',
          ),
        if (onProfileTap != null)
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 22, color: AppColors.accentCyan),
            onPressed: onProfileTap,
            tooltip: 'Профиль',
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

