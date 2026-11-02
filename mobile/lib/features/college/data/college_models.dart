/// College data: grades and assignments from SmartNation
/// (`GET /api/college/snapshot`) and the group timetable (`GET /api/timetable`).
library;

/// ISO string or epoch ms.
DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// Mark of one lesson in the SmartNation journal.
class SnGrade {
  final String? date; // YYYY-MM-DD
  final double? value;
  final String label; // «90», «Н»
  final bool absent;
  final bool failed;
  final String? theme;
  final bool isExam;

  const SnGrade({
    this.date,
    this.value,
    required this.label,
    this.absent = false,
    this.failed = false,
    this.theme,
    this.isExam = false,
  });

  factory SnGrade.fromJson(Map<String, dynamic> j) => SnGrade(
    date: j['date'] as String?,
    value: (j['value'] as num?)?.toDouble(),
    label: (j['label'] ?? '').toString(),
    absent: j['absent'] == true,
    failed: j['failed'] == true,
    theme: j['theme'] as String?,
    isExam: j['is_exam'] == true,
  );

  DateTime? get day => date == null ? null : DateTime.tryParse(date!);
}

class SnSubject {
  final String id;
  final String name;

  /// «Теоретическое обучение» / «Производственное обучение».
  final String? kind;
  final String? teacher;
  final List<SnGrade> grades;
  final double? average;
  final int absences;

  const SnSubject({
    required this.id,
    required this.name,
    this.kind,
    this.teacher,
    this.grades = const [],
    this.average,
    this.absences = 0,
  });

  factory SnSubject.fromJson(Map<String, dynamic> j) => SnSubject(
    id: j['id'].toString(),
    name: (j['name'] ?? '').toString(),
    kind: j['kind'] as String?,
    teacher: j['teacher'] as String?,
    grades: [
      for (final g in (j['grades'] as List?) ?? const [])
        SnGrade.fromJson(g as Map<String, dynamic>),
    ],
    average: (j['average'] as num?)?.toDouble(),
    absences: (j['absences'] as num?)?.toInt() ?? 0,
  );
}

/// Assignment status words used by SmartNation.
abstract final class SnStatus {
  static const checked = 'Проверено';
  static const onReview = 'На проверке';
  static const done = 'Выполнено';

  static bool isDone(String? status) =>
      status == checked || status == onReview || status == done;
}

class SnAssignment {
  final String id;
  final String title;
  final String subject;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// «В ожидании», «На проверке», «Проверено».
  final String? status;
  final num? result;
  final String? url;
  final bool closed;
  final bool isCurrent;

  const SnAssignment({
    required this.id,
    required this.title,
    required this.subject,
    this.createdAt,
    this.expiresAt,
    this.status,
    this.result,
    this.url,
    this.closed = false,
    this.isCurrent = false,
  });

  factory SnAssignment.fromJson(Map<String, dynamic> j) => SnAssignment(
    id: j['id'].toString(),
    title: (j['title'] ?? '').toString(),
    subject: (j['subject'] ?? '').toString(),
    createdAt: _date(j['created_at']),
    expiresAt: _date(j['expires_at']),
    status: j['status'] as String?,
    result: j['result'] as num?,
    url: j['url'] as String?,
    closed: j['closed'] == true,
    isCurrent: j['is_current'] == true,
  );

  bool get isDone => SnStatus.isDone(status);
}

class SnStats {
  /// Mean of all numeric marks, 0..100.
  final double? gpa;
  final int gradesCount;
  final int excellentCount;
  final int retakesCount;
  final int absences;
  final List<String> subjectsAtRisk;

  const SnStats({
    this.gpa,
    this.gradesCount = 0,
    this.excellentCount = 0,
    this.retakesCount = 0,
    this.absences = 0,
    this.subjectsAtRisk = const [],
  });

  factory SnStats.fromJson(Map<String, dynamic> j) => SnStats(
    gpa: (j['gpa'] as num?)?.toDouble(),
    gradesCount: (j['grades_count'] as num?)?.toInt() ?? 0,
    excellentCount: (j['excellent_count'] as num?)?.toInt() ?? 0,
    retakesCount: (j['retakes_count'] as num?)?.toInt() ?? 0,
    absences: (j['absences'] as num?)?.toInt() ?? 0,
    subjectsAtRisk: [
      for (final e in (j['subjects_at_risk'] as List?) ?? const [])
        e.toString(),
    ],
  );
}

/// Everything the server fetched from SmartNation for the student.
class SnSnapshot {
  final String? group;
  final int? course;
  final String? qualification;
  final String? curator;
  final List<SnSubject> subjects;
  final SnStats stats;
  final List<SnAssignment> assignments;
  final DateTime? syncedAt;

  const SnSnapshot({
    this.group,
    this.course,
    this.qualification,
    this.curator,
    this.subjects = const [],
    this.stats = const SnStats(),
    this.assignments = const [],
    this.syncedAt,
  });

  /// Open assignments, nearest deadline first.
  List<SnAssignment> get currentAssignments =>
      assignments.where((a) => a.isCurrent).toList()..sort(
        (a, b) => (a.expiresAt ?? DateTime(2100)).compareTo(
          b.expiresAt ?? DateTime(2100),
        ),
      );

  List<SnAssignment> get pastAssignments =>
      assignments.where((a) => !a.isCurrent).toList()..sort(
        (a, b) => (b.expiresAt ?? DateTime(1970)).compareTo(
          a.expiresAt ?? DateTime(1970),
        ),
      );

  factory SnSnapshot.fromJson(Map<String, dynamic> j) {
    final profile = (j['profile'] as Map<String, dynamic>?) ?? const {};
    return SnSnapshot(
      group: profile['group'] as String?,
      course: (profile['course'] as num?)?.toInt(),
      qualification: profile['qualification'] as String?,
      curator: profile['curator'] as String?,
      subjects: [
        for (final s in (j['subjects'] as List?) ?? const [])
          SnSubject.fromJson(s as Map<String, dynamic>),
      ],
      stats: SnStats.fromJson(
        (j['stats'] as Map<String, dynamic>?) ?? const {},
      ),
      assignments: [
        for (final a in (j['assignments'] as List?) ?? const [])
          SnAssignment.fromJson(a as Map<String, dynamic>),
      ],
      syncedAt: _date(j['synced_at']),
    );
  }
}

/// One pair of the college group timetable, valid from [validFrom] to
/// [validTo] inclusive.
class CollegeLesson {
  final int dayOfWeek;
  final int pairNo;
  final String startTime;
  final String endTime;
  final String subject;
  final String? teacher;
  final String? room;
  final String? validFrom; // YYYY-MM-DD
  final String? validTo;

  const CollegeLesson({
    required this.dayOfWeek,
    required this.pairNo,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.teacher,
    this.room,
    this.validFrom,
    this.validTo,
  });

  factory CollegeLesson.fromJson(Map<String, dynamic> j) => CollegeLesson(
    dayOfWeek: (j['day_of_week'] as num).toInt(),
    pairNo: (j['pair_no'] as num?)?.toInt() ?? 0,
    startTime: j['start_time'] as String,
    endTime: j['end_time'] as String,
    subject: (j['subject'] ?? '').toString(),
    teacher: j['teacher'] as String?,
    room: j['room'] as String?,
    validFrom: j['valid_from'] as String?,
    validTo: j['valid_to'] as String?,
  );
}
