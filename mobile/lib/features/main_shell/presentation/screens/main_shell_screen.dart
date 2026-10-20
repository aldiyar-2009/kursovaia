import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/sync/sync_repository.dart';
import 'package:studyplan/core/widgets/app_navigation_drawer.dart';
import 'package:studyplan/core/widgets/custom_sliver_app_bar.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/campus_map/presentation/screens/campus_map_screen.dart';
import 'package:studyplan/features/chat/presentation/screens/group_chat_screen.dart';
import 'package:studyplan/features/profile/presentation/screens/profile_screen.dart';
import 'package:studyplan/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:studyplan/features/tasks/presentation/screens/deadlines_screen.dart';
import 'package:studyplan/features/timeline/presentation/screens/timeline_screen.dart';

class MainShellScreen extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? group;
  final VoidCallback? onLogout;

  const MainShellScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.user,
    this.group,
    this.onLogout,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  AppSection _currentSection = AppSection.timeline;
  late final SyncRepository _syncRepo;
  late Map<String, dynamic> _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _syncRepo = SyncRepository(db: widget.db, apiClient: widget.apiClient);
  }

  void _onLogout() async {
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
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: AuthScreen(
            apiClient: widget.apiClient,
            db: widget.db,
          ),
        ),
      ),
      (route) => false,
    );
  }



  void _exportJson() async {
    final userId = widget.user['id'] as String;
    final subjects = await (widget.db.select(widget.db.subjects)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
        .get();
    final lessons = await (widget.db.select(widget.db.lessons)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
        .get();

    final exportData = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'subjects': subjects.map((s) => {
            'id': s.id,
            'title': s.title,
            'teacher_name': s.teacherName,
            'color_hex': s.colorHex,
          }).toList(),
      'lessons': lessons.map((l) => {
            'id': l.id,
            'subject_id': l.subjectId,
            'day_of_week': l.dayOfWeek,
            'start_time': l.startTime,
            'end_time': l.endTime,
            'classroom': l.classroom,
            'lesson_type': l.lessonType,
            'topic': l.topic,
            'is_even_week': l.isEvenWeek,
          }).toList(),
    };

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Экспорт schedule.json'),
        content: SelectableText(
          const JsonEncoder.withIndent('  ').convert(exportData),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _importJson() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функция импорта расписания готова к загрузке JSON')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUser['id'] as String;
    final userName = _currentUser['name'] as String? ?? 'Студент';
    final userRole = _currentUser['role'] as String? ?? 'student';
    final groupTitle = widget.group?['title'] as String? ?? 'ИВТ-21';
    final semester = (widget.group?['semester'] as num? ?? 3).toInt();
    final groupId = widget.group?['id'] as String? ?? '';

    return BlocProvider(
      create: (_) => SyncBloc(repository: _syncRepo, userId: userId),
      child: Scaffold(
        drawer: AppNavigationDrawer(
          currentSection: _currentSection,
          onSectionSelected: (section) {
            setState(() {
              _currentSection = section;
            });
          },
          userName: userName,
          userRole: userRole,
          groupTitle: groupTitle,
          semester: semester,
          onExportJson: _exportJson,
          onImportJson: _importJson,
          onLogout: _onLogout,
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              CustomSliverAppBar(
                selectedDate: DateTime.now(),
                onProfileTap: () {
                  setState(() {
                    _currentSection = AppSection.profile;
                  });
                },
              ),
            ];
          },
          body: _buildCurrentSection(userId, userName, userRole, groupId),
        ),
      ),
    );
  }

  Widget _buildCurrentSection(String userId, String userName, String userRole, String groupId) {
    switch (_currentSection) {
      case AppSection.timeline:
        return TimelineScreen(db: widget.db, userId: userId);
      case AppSection.schedule:
        return ScheduleCalendarScreen(db: widget.db, userId: userId);
      case AppSection.deadlines:
        return DeadlinesScreen(
          db: widget.db,
          userId: userId,
          groupId: groupId,
          isHeadman: userRole == 'headman',
        );
      case AppSection.chat:
        return GroupChatScreen(
          db: widget.db,
          userId: userId,
          userName: userName,
          userRole: userRole,
          groupId: groupId,
        );
      case AppSection.campusMap:
        return const CampusMapScreen();
      case AppSection.profile:
        return ProfileScreen(
          db: widget.db,
          apiClient: widget.apiClient,
          user: _currentUser,
          group: widget.group,
          onLogout: _onLogout,
          onUserUpdated: (updated) {

            setState(() {
              _currentUser = updated;
            });
          },
        );
    }
  }
}

