import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_state.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/announcements/data/announcements_repository.dart';
import 'package:studyplan/features/announcements/presentation/announcements_screen.dart';
import 'package:studyplan/features/auth/data/session_service.dart';
import 'package:studyplan/features/auth/presentation/account_actions.dart';
import 'package:studyplan/features/campus_map/presentation/screens/campus_map_screen.dart';
import 'package:studyplan/features/events/data/events_repository.dart';
import 'package:studyplan/features/events/presentation/events_screen.dart';
import 'package:studyplan/features/group/presentation/screens/group_screen.dart';
import 'package:studyplan/features/materials/presentation/screens/materials_screen.dart';
import 'package:studyplan/features/profile/presentation/screens/profile_screen.dart';

/// "Ещё" tab: profile & settings, group, materials, LMS import,
/// announcements, campus map and the sync status.
class MoreScreen extends StatelessWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? group;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>>? onUserUpdated;

  /// Called with the new group (null after leaving) when it changes on the
  /// group screen; `group_data` in SharedPreferences is already updated.
  final ValueChanged<Map<String, dynamic>?>? onGroupChanged;

  /// Starts the LMS import; null where it is unavailable (web).
  final VoidCallback? onImportLms;

  /// Opens the group screen (or the «account required» screen for guests).
  final VoidCallback? onOpenGroup;

  /// Demo data was cleared on the server (profile); the shell resyncs.
  final VoidCallback? onDemoCleared;

  /// College: no LMS import and no AITU campus map.
  final AppEdition edition;

  const MoreScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
    required this.user,
    this.group,
    required this.onLogout,
    this.onUserUpdated,
    this.onGroupChanged,
    this.onImportLms,
    this.onOpenGroup,
    this.onDemoCleared,
    this.edition = AppEdition.university,
  });

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  AppDeps get _deps =>
      AppDeps(db: db, apiClient: apiClient, settings: settings);

  void _openGroup(BuildContext context) {
    if (onOpenGroup != null) {
      onOpenGroup!();
      return;
    }
    _push(
      context,
      GroupScreen(
        db: db,
        apiClient: apiClient,
        userId: user['id'] as String,
        group: group,
        onGroupChanged: onGroupChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final guest = isGuestUser(user);
    final name = user['name'] as String?;
    final email = user['email'] as String?;
    final groupTitle = group?['title'] as String?;
    final college = edition.isCollege;

    return Scaffold(
      appBar: ContentAppBar(title: Text(l10n.nav_more)),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: contentPadding(constraints.maxWidth, bottom: 32),
          children: [
            // Guests have nothing to sync: their data stays on the device.
            if (!guest) ...[
              const _SyncStatusRow(),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 16),
            ListGroup(
              children: [
                if (guest)
                  ListRow(
                    key: const ValueKey('more_sign_in'),
                    title: l10n.guest_profileRow,
                    subtitle: l10n.guest_bannerMessage,
                    trailing: const ListRowChevron(),
                    onTap: () => openSignIn(context, _deps),
                  ),
                ListRow(
                  title: l10n.nav_profileSettings,
                  subtitle: guest ? l10n.guest_name : _join(name, email),
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
                      onImportLms: onImportLms,
                      onDemoCleared: onDemoCleared,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListGroup(
              children: [
                ListRow(
                  title: l10n.nav_group,
                  subtitle: guest
                      ? l10n.guest_requiredTitle
                      : groupTitle ?? l10n.nav_groupNone,
                  trailing: const ListRowChevron(),
                  onTap: () => _openGroup(context),
                ),
                ListRow(
                  key: const ValueKey('more_materials'),
                  title: l10n.nav_materials,
                  trailing: const ListRowChevron(),
                  onTap: () => _push(
                    context,
                    MaterialsScreen(
                      db: db,
                      apiClient: apiClient,
                      userId: user['id'] as String,
                      groupId: group?['id'] as String?,
                      // Group materials need an account; LMS ones are local.
                      initialTab: guest && !college ? 1 : 0,
                      showLms: !college,
                    ),
                  ),
                ),
                if (!college)
                  ListRow(
                    key: const ValueKey('more_lms_import'),
                    title: l10n.nav_lmsImport,
                    subtitle: onImportLms != null
                        ? l10n.nav_lmsImportHint
                        : l10n.nav_lmsImportWeb,
                    trailing: onImportLms != null
                        ? const ListRowChevron()
                        : null,
                    onTap: onImportLms,
                  ),
                ListRow(
                  key: const ValueKey('more_events'),
                  title: l10n.events_title,
                  trailing: const ListRowChevron(),
                  onTap: () => _push(
                    context,
                    EventsScreen(
                      db: db,
                      repository: EventsRepository(apiClient),
                      userId: user['id'] as String,
                    ),
                  ),
                ),
                ListRow(
                  key: const ValueKey('more_announcements'),
                  title: l10n.nav_announcements,
                  trailing: const ListRowChevron(),
                  onTap: () => _push(
                    context,
                    AnnouncementsScreen(
                      repository: AnnouncementsRepository(apiClient),
                    ),
                  ),
                ),
                if (!college)
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
              ],
            ),
          ],
        ),
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
          SyncStatusState.syncing => (
            l10n.nav_syncInProgress,
            palette.textSecondary,
          ),
          SyncStatusState.offlinePending => (
            l10n.nav_syncPending(state.pendingCount),
            palette.warning,
          ),
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
                    Text(l10n.nav_syncSection, style: context.text.labelSmall),
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
                // Quiet row action: secondary colour and small text, so the
                // status, not the button, is what the eye lands on.
                TextButton(
                  key: const ValueKey('more_sync_now'),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.textSecondary,
                    textStyle: context.text.labelMedium,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
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
