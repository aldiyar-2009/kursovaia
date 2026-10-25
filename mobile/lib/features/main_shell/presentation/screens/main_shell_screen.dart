import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_repository.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/grades/presentation/screens/grades_screen.dart';
import 'package:studyplan/features/group/presentation/screens/group_screen.dart';
import 'package:studyplan/features/home/presentation/screens/home_screen.dart';
import 'package:studyplan/features/more/presentation/screens/more_screen.dart';
import 'package:studyplan/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:studyplan/features/tasks/presentation/screens/deadlines_screen.dart';

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

  const MainShellScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
    required this.user,
    this.group,
    this.onLogout,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  AppTab _tab = AppTab.home;
  late final SyncRepository _syncRepo;
  late Map<String, dynamic> _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _syncRepo = SyncRepository(db: widget.db, apiClient: widget.apiClient);
  }

  void _select(AppTab tab) {
    if (tab != _tab) setState(() => _tab = tab);
  }

  Future<void> _logout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
    await prefs.remove('group_data');
    widget.apiClient.updateToken(null);

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
    final l10n = context.l10n;
    final userId = _currentUser['id'] as String;
    final groupId = widget.group?['id'] as String?;
    switch (tab) {
      case AppTab.home:
        return HomeScreen(
          db: widget.db,
          userId: userId,
          groupId: groupId,
          onOpenTab: _select,
          onOpenGroup: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupScreen(group: widget.group),
            ),
          ),
        );
      case AppTab.schedule:
        return Scaffold(
          appBar: AppBar(title: Text(l10n.nav_schedule)),
          body: ScheduleCalendarScreen(db: widget.db, userId: userId),
        );
      case AppTab.tasks:
        return Scaffold(
          appBar: AppBar(title: Text(l10n.nav_tasks)),
          body: DeadlinesScreen(
            db: widget.db,
            userId: userId,
            groupId: groupId,
            // Roles are gone: every group member may publish group tasks.
            isHeadman: groupId != null && groupId.isNotEmpty,
          ),
        );
      case AppTab.grades:
        return Scaffold(
          appBar: AppBar(title: Text(l10n.nav_grades)),
          body: const GradesScreen(),
        );
      case AppTab.more:
        return MoreScreen(
          db: widget.db,
          apiClient: widget.apiClient,
          settings: widget.settings,
          user: _currentUser,
          group: widget.group,
          onLogout: _logout,
          onUserUpdated: (updated) => setState(() => _currentUser = updated),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUser['id'] as String;
    final destinations = _destinations(context);
    final body = IndexedStack(
      index: _tab.index,
      children: [
        for (final tab in AppTab.values)
          // Each tab keeps its own navigator-free subtree alive.
          KeyedSubtree(key: ValueKey(tab), child: _tabBody(tab, context)),
      ],
    );

    return BlocProvider(
      create: (_) => SyncBloc(repository: _syncRepo, userId: userId),
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
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }
            final extended = width >= kExtendedRailBreakpoint;
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    extended: extended,
                    minExtendedWidth: 220,
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    selectedIndex: _tab.index,
                    onDestinationSelected: (i) => _select(AppTab.values[i]),
                    leading: _RailHeader(extended: extended),
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

class _RailHeader extends StatelessWidget {
  final bool extended;

  const _RailHeader({required this.extended});

  @override
  Widget build(BuildContext context) {
    if (!extended) return const SizedBox(height: 8);
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
        child: Text(
          context.l10n.common_appName,
          style: context.text.titleMedium,
        ),
      ),
    );
  }
}
