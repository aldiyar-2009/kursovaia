import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_repository.dart';
import 'package:studyplan/core/sync/sync_state.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/grades/presentation/screens/grades_screen.dart';
import 'package:studyplan/features/lms/presentation/lms_import_screen.dart';
import 'package:studyplan/features/group/presentation/screens/group_screen.dart';
import 'package:studyplan/features/home/presentation/screens/home_screen.dart';
import 'package:studyplan/features/main_shell/data/session_cleanup.dart';
import 'package:studyplan/features/more/presentation/screens/more_screen.dart';
import 'package:studyplan/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:studyplan/features/tasks/presentation/screens/tasks_screen.dart';

enum AppTab { home, schedule, tasks, grades, more }

/// Width from which the bottom bar becomes a side rail.
const double kRailBreakpoint = 840;

/// Width from which the rail shows labels next to icons.
const double kExtendedRailBreakpoint = 1200;

class MainShellScreen extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? group;
  final VoidCallback? onLogout;

  /// Sync repository override (tests); built from [db] and [apiClient]
  /// otherwise.
  final SyncRepository? syncRepository;

  const MainShellScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
    required this.user,
    this.group,
    this.onLogout,
    this.syncRepository,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  AppTab _tab = AppTab.home;
  late final SyncRepository _syncRepo;
  late final SyncBloc _syncBloc;
  late Map<String, dynamic> _currentUser;
  Map<String, dynamic>? _group;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _group = widget.group;
    _syncRepo = widget.syncRepository ??
        SyncRepository(db: widget.db, apiClient: widget.apiClient);
    _syncBloc = SyncBloc(
      repository: _syncRepo,
      userId: _currentUser['id'] as String,
    );
    WidgetsBinding.instance.addObserver(this);
    // Sync as soon as the shell is on screen (fresh login, app start).
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncBloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requestSync();
  }

  /// SyncBloc ignores the request while a sync is already running.
  void _requestSync() {
    if (!mounted || _syncBloc.isClosed) return;
    _syncBloc.add(SyncTriggered());
  }

  /// Group joined, created or left (from Group, More or Materials): rows the
  /// group published before the change are older than the sync cursor, so
  /// the cursor is reset and a full sync runs.
  void _onGroupChanged(Map<String, dynamic>? group) {
    final changedGroup = group?['id'] != _group?['id'];
    setState(() => _group = group);
    if (changedGroup) resyncAfterGroupChange(_syncBloc);
  }

  /// Opens the Microsoft/LMS import flow; null where import is unavailable (web).
  VoidCallback? _lmsImportAction(String userId) {
    if (!isLmsImportSupported) return null;
    return () async {
      final summary = await openLmsImport(
        context,
        db: widget.db,
        userId: userId,
        beforeApply: _syncAndWait,
      );
      if (summary != null) _syncBloc.add(SyncTriggered());
    };
  }

  /// Pushes local edits (e.g. credits changed on another device) before an
  /// LMS import overwrites rows; the import caps the wait itself.
  Future<void> _syncAndWait() async {
    if (_syncBloc.isClosed) return;
    final done = _syncBloc.stream
        .firstWhere((s) => s.status != SyncStatusState.syncing);
    _syncBloc.add(SyncTriggered());
    await done;
  }

  void _select(AppTab tab) {
    if (tab != _tab) setState(() => _tab = tab);
  }

  Future<void> _logout() async {
    widget.apiClient.updateToken(null);
    // Token, sync cursor, caches and the local database of this user.
    // LMS/Microsoft cookies too, so the next user cannot import this account.
    await clearLocalSession(widget.db, clearWebSession: clearLmsWebSession);
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(
          apiClient: widget.apiClient,
          db: widget.db,
          settings: widget.settings,
        ),
      ),
      (route) => false,
    );
  }

  List<({IconData icon, String label})> _destinations(BuildContext context) {
    final l10n = context.l10n;
    return [
      (icon: Icons.home_outlined, label: l10n.nav_home),
      (icon: Icons.calendar_today_outlined, label: l10n.nav_schedule),
      (icon: Icons.check_circle_outline, label: l10n.nav_tasks),
      (icon: Icons.school_outlined, label: l10n.nav_grades),
      (icon: Icons.more_horiz, label: l10n.nav_more),
    ];
  }

  Widget _tabBody(AppTab tab, BuildContext context) {
    final userId = _currentUser['id'] as String;
    final groupId = _group?['id'] as String?;
    switch (tab) {
      case AppTab.home:
        return HomeScreen(
          db: widget.db,
          userId: userId,
          groupId: groupId,
          onOpenTab: _select,
          onOpenGroup: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupScreen(
                db: widget.db,
                apiClient: widget.apiClient,
                userId: userId,
                group: _group,
                onGroupChanged: _onGroupChanged,
              ),
            ),
          ),
        );
      case AppTab.schedule:
        final semesterStart = _group?['semester_start'];
        return ScheduleScreen(
          db: widget.db,
          userId: userId,
          semesterStart: semesterStart is String
              ? DateTime.tryParse(semesterStart)
              : null,
        );
      case AppTab.tasks:
        return TasksScreen(
          db: widget.db,
          userId: userId,
          group: _group,
          onOpenGroup: () => _select(AppTab.more),
        );
      case AppTab.grades:
        // GradesScreen has its own AppBar (import / add actions).
        return GradesScreen(
          db: widget.db,
          userId: userId,
          onImportLms: _lmsImportAction(userId),
        );
      case AppTab.more:
        return MoreScreen(
          db: widget.db,
          apiClient: widget.apiClient,
          settings: widget.settings,
          user: _currentUser,
          group: _group,
          onLogout: _logout,
          onUserUpdated: (updated) => setState(() => _currentUser = updated),
          onGroupChanged: _onGroupChanged,
          onImportLms: _lmsImportAction(userId),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context);
    final body = IndexedStack(
      index: _tab.index,
      children: [
        for (final tab in AppTab.values)
          // Each tab keeps its own navigator-free subtree alive.
          KeyedSubtree(key: ValueKey(tab), child: _tabBody(tab, context)),
      ],
    );

    return BlocProvider.value(
      value: _syncBloc,
      child: PopScope(
        canPop: _tab == AppTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _select(AppTab.home);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width < kRailBreakpoint) {
              return Scaffold(
                body: body,
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 1),
                    NavigationBar(
                      selectedIndex: _tab.index,
                      onDestinationSelected: (i) => _select(AppTab.values[i]),
                      destinations: [
                        for (final d in destinations)
                          NavigationDestination(
                            icon: Icon(d.icon),
                            label: d.label,
                            // The label is always visible; a hover tooltip
                            // would only repeat it.
                            tooltip: '',
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }
            // M3 NavigationRail draws its indicator around the icon only, even
            // when extended; the wide layout uses a sidebar whose selection
            // covers the whole row instead.
            final extended = width >= kExtendedRailBreakpoint;
            return Scaffold(
              body: Row(
                children: [
                  if (extended)
                    _Sidebar(
                      destinations: destinations,
                      selectedIndex: _tab.index,
                      onSelected: (i) => _select(AppTab.values[i]),
                    )
                  else
                    NavigationRail(
                      labelType: NavigationRailLabelType.all,
                      selectedIndex: _tab.index,
                      onDestinationSelected: (i) => _select(AppTab.values[i]),
                      leading: const SizedBox(height: 8),
                      destinations: [
                        for (final d in destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: body),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Width of the labelled sidebar on wide windows.
const double kSidebarWidth = 220;

/// Labelled navigation for windows >= [kExtendedRailBreakpoint]: the
/// selected destination is highlighted across the full row.
class _Sidebar extends StatelessWidget {
  final List<({IconData icon, String label})> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: kSidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Text(
                  context.l10n.common_appName,
                  style: context.text.titleMedium,
                ),
              ),
              for (var i = 0; i < destinations.length; i++)
                _SidebarItem(
                  icon: destinations[i].icon,
                  label: destinations[i].label,
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.textPrimary : p.textSecondary;
    const radius = BorderRadius.all(Radius.circular(AppRadius.md));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? p.surfaceMuted : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? p.textPrimary : p.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge!.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
