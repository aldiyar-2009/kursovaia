import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/features/grades/data/models/grade_models.dart';

class AituDataService extends ChangeNotifier {
  static final AituDataService _instance = AituDataService._internal();
  factory AituDataService() => _instance;
  AituDataService._internal() {
    _initInitialData();
  }

  String _currentGroup = 'BDA-2601';
  String get currentGroup => _currentGroup;

  bool _isLmsConnected = true;
  bool get isLmsConnected => _isLmsConnected;

  DateTime _lastSyncTime = DateTime.now();
  DateTime get lastSyncTime => _lastSyncTime;

  final List<SubjectGrade> _subjects = [];
  final List<RetakeItem> _retakes = [];

  List<SubjectGrade> get subjects => List.unmodifiable(_subjects);
  List<RetakeItem> get retakes => List.unmodifiable(_retakes);

  String _studentName = 'Студент';
  String get studentName => _studentName;

  void setGroup(String group) {
    if (_currentGroup == group) return;
    _currentGroup = group;
    _initInitialData();
    notifyListeners();
  }

  Future<Map<String, dynamic>> loginLms(String username, String password) async {
    try {
      final client = ApiClient();
      final res = await client.dio.post('/lms/login', data: {
        'username': username,
        'password': password,
      });

      if (res.data != null && res.data['success'] == true) {
        final data = res.data;
        if (data['student'] != null && data['student']['name'] != null) {
          _studentName = data['student']['name'];
        }

        final parsedCourses = data['courses'] as List<dynamic>? ?? [];
        if (parsedCourses.isNotEmpty) {
          _subjects.clear();
          for (int i = 0; i < parsedCourses.length; i++) {
            final c = parsedCourses[i];
            final score = (c['grade'] as num?)?.toDouble() ?? 85.0;
            _subjects.add(
              SubjectGrade(
                id: 'lms_$i',
                name: c['title'] ?? 'Дисциплина',
                teacher: c['teacher'] ?? 'Преподаватель AITU',
                average: score > 0 ? score : 85.0,
                grades: [
                  LessonGrade(id: 'g_${i}_1', score: score > 0 ? score.toInt() : 85, date: 'Текущий'),
                ],
              ),
            );
          }
        }

        _isLmsConnected = true;
        _lastSyncTime = DateTime.now();
        notifyListeners();
        return {'success': true};
      }

      return {'success': false, 'error': res.data?['error'] ?? 'Не удалось авторизоваться в LMS AITU'};
    } catch (e) {
      if (e is DioException && e.response?.data != null && e.response?.data['error'] != null) {
        return {'success': false, 'error': e.response!.data['error']};
      }
      return {'success': false, 'error': 'Ошибка соединения с сервером LMS AITU'};
    }
  }

  void connectLms({String login = 'student@astanait.edu.kz', bool isDemo = false}) {
    if (isDemo) {
      _studentName = 'Студент';
    }
    _isLmsConnected = true;
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }

  void refreshData() {
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }

  void _initInitialData() {
    _subjects.clear();
    _retakes.clear();

    _subjects.addAll([
      SubjectGrade(
        id: 'sub_1',
        name: 'Introduction to Programming',
        teacher: 'Кафедра Computer Science',
        average: 89.4,
        grades: [
          const LessonGrade(id: 'g_1', score: 85, date: '02.10'),
          const LessonGrade(id: 'g_2', score: 90, date: '06.10'),
          const LessonGrade(id: 'g_3', score: 92, date: '10.10'),
          const LessonGrade(id: 'g_4', score: 90, date: '14.10'),
        ],
      ),
      SubjectGrade(
        id: 'sub_2',
        name: 'Calculus 1',
        teacher: 'Кафедра высшей математики',
        average: 84.5,
        grades: [
          const LessonGrade(id: 'g_5', score: 80, date: '02.10'),
          const LessonGrade(id: 'g_6', score: 85, date: '06.10'),
          const LessonGrade(id: 'g_7', score: 88, date: '12.10'),
        ],
      ),
      SubjectGrade(
        id: 'sub_3',
        name: 'Information & Comm. Technologies',
        teacher: 'Кафедра информационных технологий',
        average: 93.0,
        grades: [
          const LessonGrade(id: 'g_8', score: 90, date: '03.10'),
          const LessonGrade(id: 'g_9', score: 95, date: '08.10'),
          const LessonGrade(id: 'g_10', score: 94, date: '15.10'),
        ],
      ),
      SubjectGrade(
        id: 'sub_4',
        name: 'Discrete Mathematics',
        teacher: 'Кафедра математического моделирования',
        average: 78.5,
        grades: [
          const LessonGrade(id: 'g_11', score: 75, date: '04.10'),
          const LessonGrade(id: 'g_12', score: 82, date: '11.10'),
        ],
      ),
      SubjectGrade(
        id: 'sub_5',
        name: 'Foreign Language (English for IT)',
        teacher: 'Кафедра языковых дисциплин',
        average: 91.5,
        grades: [
          const LessonGrade(id: 'g_13', score: 90, date: '05.10'),
          const LessonGrade(id: 'g_14', score: 93, date: '12.10'),
        ],
      ),
      SubjectGrade(
        id: 'sub_6',
        name: 'History of Kazakhstan',
        teacher: 'Кафедра социально-гуманитарных наук',
        average: 88.0,
        grades: [
          const LessonGrade(id: 'g_15', score: 86, date: '01.10'),
          const LessonGrade(id: 'g_16', score: 90, date: '09.10'),
        ],
      ),
      SubjectGrade(
        id: 'sub_7',
        name: 'Physical Education',
        teacher: 'Спортивно-оздоровительный комплекс',
        average: 96.0,
        grades: [
          const LessonGrade(id: 'g_17', score: 95, date: '02.10'),
          const LessonGrade(id: 'g_18', score: 97, date: '10.10'),
        ],
      ),
    ]);

    _retakes.addAll([
      RetakeItem(
        id: 'retake_1',
        subjectName: 'Discrete Mathematics (Quiz 1)',
        teacherName: 'Кафедра математического моделирования',
        score: 48,
        date: '2026-10-14',
        status: 'Нужно отработать',
        targetScore: 80,
      ),
    ]);
  }

  double get overallAverage {
    if (_subjects.isEmpty) return 0.0;
    final sum = _subjects.fold<double>(0.0, (acc, s) => acc + s.average);
    return double.parse((sum / _subjects.length).toStringAsFixed(1));
  }

  int get excellentCount => _subjects.where((s) => s.average >= 90).length;

  int get retakesSubjectsCount => _subjects.where((s) => s.average < 51 || s.retakesCount > 0).length;

  void addVirtualGrade(String subjectId, int score) {
    final idx = _subjects.indexWhere((s) => s.id == subjectId);
    if (idx == -1) return;

    final subject = _subjects[idx];
    final updatedGrades = List<LessonGrade>.from(subject.grades)
      ..add(
        LessonGrade(
          id: 'virt_${DateTime.now().millisecondsSinceEpoch}',
          score: score,
          date: 'Прогноз',
          type: 'Виртуальная оценка',
          isVirtual: true,
        ),
      );

    final totalScore = updatedGrades.fold<int>(0, (sum, g) => sum + g.score);
    final newAvg = double.parse((totalScore / updatedGrades.length).toStringAsFixed(1));

    _subjects[idx] = SubjectGrade(
      id: subject.id,
      name: subject.name,
      teacher: subject.teacher,
      average: newAvg,
      grades: updatedGrades,
      retakesCount: newAvg < 51 ? subject.retakesCount : 0,
      hasWarning: newAvg < 51,
    );
    notifyListeners();
  }

  void removeVirtualGrade(String subjectId, String gradeId) {
    final idx = _subjects.indexWhere((s) => s.id == subjectId);
    if (idx == -1) return;

    final subject = _subjects[idx];
    final updatedGrades = subject.grades.where((g) => g.id != gradeId).toList();

    double newAvg = subject.average;
    if (updatedGrades.isNotEmpty) {
      final totalScore = updatedGrades.fold<int>(0, (sum, g) => sum + g.score);
      newAvg = double.parse((totalScore / updatedGrades.length).toStringAsFixed(1));
    }

    _subjects[idx] = SubjectGrade(
      id: subject.id,
      name: subject.name,
      teacher: subject.teacher,
      average: newAvg,
      grades: updatedGrades,
      retakesCount: newAvg < 51 ? 1 : 0,
      hasWarning: newAvg < 51,
    );
    notifyListeners();
  }

  void clearVirtualGrades() {
    _initInitialData();
    notifyListeners();
  }

  void updateRetakeStatus(String retakeId, String newStatus, int targetScore) {
    final idx = _retakes.indexWhere((r) => r.id == retakeId);
    if (idx != -1) {
      _retakes[idx].status = newStatus;
      _retakes[idx].targetScore = targetScore;
      notifyListeners();
    }
  }

  static const List<Map<String, dynamic>> universityGroups = [
    {
      'course': '1-й курс (Бакалавриат)',
      'groups': ['BDA-2601', 'CS-2602', 'SE-2603', 'IT-2604', 'CYBER-2605', 'MT-2606', 'JRN-2607'],
    },
    {
      'course': '2-й курс (Бакалавриат)',
      'groups': ['BDA-2501', 'CS-2502', 'SE-2503', 'IT-2504', 'CYBER-2505', 'MT-2506'],
    },
    {
      'course': '3-й курс (Бакалавриат)',
      'groups': ['BDA-2401', 'CS-2402', 'SE-2403', 'IT-2404', 'CYBER-2405'],
    },
  ];
}
