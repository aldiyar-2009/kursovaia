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
import 'package:studyplan/features/admin/presentation/screens/admin_panel_screen.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/files/presentation/screens/files_screen.dart';
import 'package:studyplan/features/calendar/presentation/screens/academic_calendar_screen.dart';
import 'package:studyplan/features/campus_map/presentation/screens/campus_map_screen.dart';
import 'package:studyplan/features/grades/presentation/screens/grades_screen.dart';
import 'package:studyplan/features/portal/presentation/screens/portal_screen.dart';
import 'package:studyplan/features/profile/presentation/screens/profile_screen.dart';
import 'package:studyplan/features/reminders/presentation/screens/reminders_screen.dart';
import 'package:studyplan/features/retakes/presentation/screens/retakes_screen.dart';
import 'package:studyplan/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:studyplan/features/scholarship/presentation/screens/scholarship_screen.dart';
import 'package:studyplan/features/simulator/presentation/screens/simulator_screen.dart';
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
  AppSection _currentSection = AppSection.portal;
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

  String _getSectionTitle() {
    switch (_currentSection) {
      case AppSection.portal:
        return 'Главная · Astana IT University';
      case AppSection.timeline:
        return 'Таймлайн дня';
      case AppSection.schedule:
        return 'Расписание пар';
      case AppSection.deadlines:
        return 'Домашние задания';
      case AppSection.grades:
        return 'Оценки';
      case AppSection.simulator:
        return 'Симулятор баллов';
      case AppSection.retakes:
        return 'Отработки';
      case AppSection.scholarship:
        return 'Повышенная стипендия';
      case AppSection.calendar:
        return 'Учебный календарь';
      case AppSection.files:
        return 'Файлы и материалы';
      case AppSection.campusMap:
        return 'Карта AITU';
      case AppSection.reminders:
        return 'Напоминания';
      case AppSection.chat:
        return 'Чат группы';
      case AppSection.admin:
        return 'Администрирование';
      case AppSection.profile:
        return 'Мой профиль';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUser['id'] as String;
    final userName = _currentUser['name'] as String? ?? 'Студент';
    final userRole = _currentUser['role'] as String? ?? 'student';
    final groupTitle = widget.group?['title'] as String? ?? 'BDA-2601';
    final semester = (widget.group?['semester'] as num? ?? 1).toInt();
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
                sectionTitle: _getSectionTitle(),
                onProfileTap: () {
                  setState(() {
                    _currentSection = AppSection.profile;
                  });
                },
              ),
            ];
          },
          body: _buildCurrentSection(userId, userName, userRole, groupId, groupTitle),
        ),
      ),
    );
  }

  Widget _buildCurrentSection(String userId, String userName, String userRole, String groupId, String groupTitle) {
    switch (_currentSection) {
      case AppSection.portal:
        return PortalScreen(
          userName: userName,
          userRole: userRole,
          onNavigate: (sec) => setState(() => _currentSection = sec),
        );
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
      case AppSection.grades:
        return GradesScreen(
          onOpenSimulator: () => setState(() => _currentSection = AppSection.simulator),
        );
      case AppSection.simulator:
        return const SimulatorScreen();
      case AppSection.retakes:
        return const RetakesScreen();
      case AppSection.scholarship:
        return ScholarshipScreen(
          onOpenSimulator: () => setState(() => _currentSection = AppSection.simulator),
        );
      case AppSection.calendar:
        return const AcademicCalendarScreen();
      case AppSection.files:
        return const FilesScreen();
      case AppSection.campusMap:
        return const CampusMapScreen();
      case AppSection.reminders:
        return const RemindersScreen();
      case AppSection.chat:
        return const SizedBox.shrink();
      case AppSection.admin:
        return AdminPanelScreen(
          userRole: userRole,
          groupTitle: groupTitle,
        );
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
