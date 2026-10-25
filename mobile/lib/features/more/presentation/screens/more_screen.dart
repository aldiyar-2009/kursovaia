import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_state.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/campus_map/presentation/screens/campus_map_screen.dart';
import 'package:studyplan/features/group/presentation/screens/group_screen.dart';
import 'package:studyplan/features/profile/presentation/screens/profile_screen.dart';

/// "Ещё" tab: group, campus map, profile & settings, sync status.
class MoreScreen extends StatelessWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? group;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>>? onUserUpdated;

  const MoreScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
    required this.user,
    this.group,
    required this.onLogout,
    this.onUserUpdated,
  });

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = user['name'] as String?;
    final email = user['email'] as String?;
    final groupTitle = group?['title'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.nav_more)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _SyncStatusRow(),
          const SizedBox(height: 8),
          ListGroup(children: [
            ListRow(
              title: l10n.nav_profileSettings,
              subtitle: _join(name, email),
              trailing: const ListRowChevron(),
              onTap: () => _push(
                context,
                ProfileScreen(
                  db: db,
                  apiClient: apiClient,
                  settings: settings,
                  user: user,
                  group: group,
                  onLogout: onLogout,
                  onUserUpdated: onUserUpdated,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          ListGroup(children: [
            ListRow(
              title: l10n.nav_group,
              subtitle: groupTitle ?? l10n.nav_groupNone,
              trailing: const ListRowChevron(),
              onTap: () => _push(context, GroupScreen(group: group)),
            ),
            ListRow(
              title: l10n.nav_campusMap,
              trailing: const ListRowChevron(),
              onTap: () => _push(
                context,
                Scaffold(
                  appBar: AppBar(title: Text(l10n.nav_campusMap)),
                  body: const CampusMapScreen(),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static String? _join(String? a, String? b) {
    final parts = [a, b].whereType<String>().where((s) => s.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Header row with the sync state and a manual sync button.
class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        final syncing = state.status == SyncStatusState.syncing;
        final (String text, Color color) = switch (state.status) {
          SyncStatusState.syncing => (l10n.nav_syncInProgress, palette.textSecondary),
          SyncStatusState.offlinePending =>
            (l10n.nav_syncPending(state.pendingCount), palette.warning),
          SyncStatusState.error => (l10n.nav_syncError, palette.danger),
          SyncStatusState.synced => (
              state.lastSyncedAt == null
                  ? l10n.nav_syncDone
                  : l10n.nav_syncDoneAt(
                      DateFormat.Hm(Localizations.localeOf(context).toString())
                          .format(state.lastSyncedAt!),
                    ),
              palette.textSecondary,
            ),
        };
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.nav_syncSection,
                      style: context.text.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall!.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              if (syncing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton(
                  onPressed: () =>
                      context.read<SyncBloc>().add(SyncTriggered()),
                  child: Text(l10n.nav_syncNow),
                ),
            ],
          ),
        );
      },
    );
  }
}
