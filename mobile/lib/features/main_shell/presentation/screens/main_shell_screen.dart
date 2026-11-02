import 'dart:async';

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
import 'package:studyplan/core/widgets/ui/account_banner.dart';
import 'package:studyplan/features/auth/data/session_service.dart';
import 'package:studyplan/features/auth/presentation/account_actions.dart';
import 'package:studyplan/features/college/data/college_repository.dart';
import 'package:studyplan/features/college/presentation/college_assignments_view.dart';
import 'package:studyplan/features/college/presentation/college_grades_screen.dart';
import 'package:studyplan/features/grades/presentation/screens/grades_screen.dart';
import 'package:studyplan/features/lms/presentation/lms_import_screen.dart';
import 'package:studyplan/features/group/presentation/screens/group_screen.dart';
import 'package:studyplan/features/home/presentation/screens/home_screen.dart';
import 'package:studyplan/features/main_shell/data/session_cleanup.dart';
import 'package:studyplan/features/more/presentation/screens/more_screen.dart';
import 'package:studyplan/features/schedule/presentation/screens/schedule_exchange_screen.dart';
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
  StreamSubscription<AuthFailure>? _authFailures;
  bool _demoStarting = false;

  /// No account: data stays on the device, server features ask to sign in.
  bool get _isGuest => isGuestUser(_currentUser);
  bool get _isDemo => isDemoUser(_currentUser);

  /// University (LMS) or college (SmartNation); guests use the edition
  /// chosen on the first screen.
  AppEdition get _edition =>
      AppEdition.ofUser(_currentUser, fallback: widget.settings.edition);
  bool get _isCollege => _edition.isCollege;

  late final CollegeRepository _collegeRepo = CollegeRepository(
    apiClient: widget.apiClient,
    db: widget.db,
  );
  bool _importingTimetable = false;

  AppDeps get _deps => AppDeps(
    db: widget.db,
    apiClient: widget.apiClient,
    settings: widget.settings,
  );

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _group = widget.group;
    _syncRepo =
        widget.syncRepository ??
        SyncRepository(db: widget.db, apiClient: widget.apiClient);
    _syncBloc = SyncBloc(
      repository: _syncRepo,
      userId: _currentUser['id'] as String,
      localOnly: _isGuest,
      listenToConnectivity: !_isGuest,
    );
    _authFailures = widget.apiClient.authFailures.listen(_onAuthFailure);
    WidgetsBinding.instance.addObserver(this);
    // Sync as soon as the shell is on screen (fresh login, app start).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestSync();
      if (_isCollege && !_isGuest) _autoImportTimetable();
    });
  }

  /// First college sign-in: the group timetable from SmartNation's group
  /// name is loaded once without asking.
  Future<void> _autoImportTimetable() async {
    if (await CollegeRepository.savedGroup() != null) return;
    final group = _currentUser['sn_group'];
    if (group is! String || group.isEmpty) return;
    try {
      await _collegeRepo.importTimetable(_currentUser['id'] as String, group);
      _requestSync();
    } catch (_) {
      // Offline: the schedule offers «load group timetable» itself.
    }
  }

  /// Loads or refreshes the college group timetable; asks for the group
  /// when it is unknown (guests).
  Future<void> _importTimetable() async {
    if (_importingTimetable) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importingTimetable = true);
    try {
      var group = await CollegeRepository.savedGroup();
      final own = _currentUser['sn_group'];
      if (own is String && own.isNotEmpty) group = own;
      if (group == null || group.isEmpty) {
        final groups = await _collegeRepo.timetableGroups();
        if (!mounted) return;
        group = await _pickGroup(groups);
        if (group == null) return;
      }
      final count = await _collegeRepo.importTimetable(
        _currentUser['id'] as String,
        group,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? l10n.college_timetableEmptyGroup(group)
                : l10n.college_timetableDone(group, count),
          ),
        ),
      );
      _requestSync();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.college_timetableFailed)),
      );
    } finally {
      if (mounted) setState(() => _importingTimetable = false);
    }
  }

  Future<String?> _pickGroup(List<String> groups) {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.college_timetablePick),
        children: [
          for (final g in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(g),
              child: Text(g),
            ),
        ],
      ),
    );
  }

  void _openExchange() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScheduleExchangeScreen(
          db: widget.db,
          userId: _currentUser['id'] as String,
          groupName: _group?['title'] as String?,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authFailures?.cancel();
    _syncBloc.close();
    super.dispose();
  }

  /// The server rejected the saved session (token expired or account
  /// blocked by an administrator): explain why and sign out.
  void _onAuthFailure(AuthFailure failure) {
    if (_isGuest || !mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    _authFailures?.cancel();
    _logout().then(
      (_) => messenger?.showSnackBar(
        SnackBar(
          content: Text(
            failure == AuthFailure.blocked
                ? l10n.session_blocked
                : l10n.session_expired,
          ),
        ),
      ),
    );
  }

  Future<void> _startDemo() async {
    setState(() => _demoStarting = true);
    final ok = await startDemo(context, _deps);
    if (!ok && mounted) setState(() => _demoStarting = false);
  }

  /// Demo data cleared on the server: pull the tombstones from scratch.
  void _onDemoCleared() => resyncAfterGroupChange(_syncBloc);

  void _openGroup(BuildContext context) {
    final l10n = context.l10n;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _isGuest
            ? AccountRequiredScreen(title: l10n.nav_group, deps: _deps)
            : GroupScreen(
                db: widget.db,
                apiClient: widget.apiClient,
                userId: _currentUser['id'] as String,
                group: _group,
                onGroupChanged: _onGroupChanged,
              ),
      ),
    );
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
    if (_isCollege || !isLmsImportSupported) return null;
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
    final done = _syncBloc.stream.firstWhere(
      (s) => s.status != SyncStatusState.syncing,
    );
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
    // Back to the «university or college» choice, then sign-in or demo.
    openStart(context, _deps);
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
          onOpenGroup: () => _openGroup(context),
          apiClient: widget.apiClient,
          isCollege: _isCollege,
        );
      case AppTab.schedule:
        final semesterStart = _group?['semester_start'];
        return ScheduleScreen(
          db: widget.db,
          userId: userId,
          semesterStart: semesterStart is String
              ? DateTime.tryParse(semesterStart)
              : null,
          onImportTimetable: _isCollege ? _importTimetable : null,
          onOpenExchange: _openExchange,
        );
      case AppTab.tasks:
        return TasksScreen(
          db: widget.db,
          userId: userId,
          group: _group,
          onOpenGroup: () => _select(AppTab.more),
          collegeAssignments: _isCollege
              ? CollegeAssignmentsView(
                  db: widget.db,
                  userId: userId,
                  repository: _isGuest ? null : _collegeRepo,
                )
              : null,
        );
      case AppTab.grades:
        if (_isCollege) {
          return CollegeGradesScreen(
            repository: _isGuest ? null : _collegeRepo,
            onSignIn: () => openSignIn(context, _deps),
          );
        }
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
          onOpenGroup: () => _openGroup(context),
          onDemoCleared: _onDemoCleared,
          edition: _edition,
        );
    }
  }

  /// Guest / demo banner above every tab; null for a regular account.
  Widget? _banner(BuildContext context) {
    final l10n = context.l10n;
    if (_isGuest) {
      return AccountBanner(
        key: const ValueKey('guest_banner'),
        title: l10n.guest_bannerTitle,
        message: l10n.guest_bannerMessage,
        primaryLabel: l10n.guest_signIn,
        onPrimary: () => openSignIn(context, _deps),
        secondaryLabel: l10n.guest_demo,
        onSecondary: _startDemo,
        busy: _demoStarting,
      );
    }
    if (_isDemo) {
      return AccountBanner(
        key: const ValueKey('demo_banner'),
        title: l10n.guest_demo,
        message: l10n.demo_bannerMessage,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context);
    final tabs = IndexedStack(
      index: _tab.index,
      children: [
        for (final tab in AppTab.values)
          // Each tab keeps its own navigator-free subtree alive.
          KeyedSubtree(key: ValueKey(tab), child: _tabBody(tab, context)),
      ],
    );
    final banner = _banner(context);
    final body = banner == null
        ? tabs
        : Column(
            children: [
              banner,
              // The banner already takes the status bar inset.
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: tabs,
                ),
              ),
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
