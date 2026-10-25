/// Plain data parsed from Moodle (lms.astanait.edu.kz). No Flutter, no I/O.
///
/// All score fields are nullable: `null` means «нет оценки» and must never be
/// shown or averaged as 0.
library;

import 'dart:convert';

/// A course as seen by the student, with its grade components.
class LmsCourseData {
  const LmsCourseData({
    required this.lmsCourseId,
    required this.title,
    this.teacherName,
    this.classification,
    this.total,
    this.midterm,
    this.endterm,
    this.finalExam,
    this.gradeItemsJson,
  });

  final int lmsCourseId;
  final String title;
  final String? teacherName;

  /// Moodle timeline classification: `inprogress`, `past`, `future`, … .
  final String? classification;
  final double? total;
  final double? midterm;
  final double? endterm;
  final double? finalExam;

  /// JSON list of `{name: String, grade: double?, range: String?}`.
  final String? gradeItemsJson;

  LmsCourseData copyWith({
    String? title,
    String? teacherName,
    String? classification,
    double? total,
    double? midterm,
    double? endterm,
    double? finalExam,
    String? gradeItemsJson,
  }) {
    return LmsCourseData(
      lmsCourseId: lmsCourseId,
      title: title ?? this.title,
      teacherName: teacherName ?? this.teacherName,
      classification: classification ?? this.classification,
      total: total ?? this.total,
      midterm: midterm ?? this.midterm,
      endterm: endterm ?? this.endterm,
      finalExam: finalExam ?? this.finalExam,
      gradeItemsJson: gradeItemsJson ?? this.gradeItemsJson,
    );
  }

  @override
  String toString() =>
      'LmsCourseData($lmsCourseId, $title, teacher: $teacherName, total: $total, '
      'mid: $midterm, end: $endterm, final: $finalExam)';
}

/// One row of a Moodle grade report (an activity or a category total).
class LmsGradeItem {
  const LmsGradeItem({required this.name, this.grade, this.range});

  final String name;
  final double? grade;
  final String? range;

  Map<String, dynamic> toJson() => {
    'name': name,
    'grade': grade,
    'range': range,
  };
}

// Item-name patterns per component, in priority order: the first pattern that
// matches any item wins, so «Register Midterm» beats a plain «Midterm exam».
const _midtermPatterns = [
  'register midterm',
  'midterm',
  'рубежный контроль 1',
  '1-ші аралық',
];
const _endtermPatterns = ['register endterm', 'endterm', 'рубежный контроль 2'];
const _finalPatterns = ['final', 'финал', 'экзамен', 'емтихан'];

LmsGradeItem? _pick(
  List<LmsGradeItem> items,
  List<String> patterns, {
  Set<LmsGradeItem> exclude = const {},
}) {
  for (final p in patterns) {
    for (final item in items) {
      if (exclude.contains(item)) continue;
      if (item.name.toLowerCase().contains(p)) return item;
    }
  }
  return null;
}

/// Shared by the HTML and AJAX grade parsers: fills midterm / endterm / final
/// from [items] by name (case-insensitive) and stores [items] as
/// `gradeItemsJson`.
///
/// Every grade and [courseTotal] must already be a percent; they are clamped
/// to 0..100 here (non-finite → `null`).
///
/// Rule «нет оценки»: when no item has a grade yet, every score (including
/// [courseTotal], which Moodle shows as `0,00` at semester start) is `null`.
/// Empty [items] means the report could not be read: [base] is returned as is.
LmsCourseData applyGradeItemList(
  LmsCourseData base,
  List<LmsGradeItem> items, {
  double? courseTotal,
}) {
  if (items.isEmpty) return base;
  final clamped = [
    for (final i in items)
      LmsGradeItem(name: i.name, grade: clampPercent(i.grade), range: i.range),
  ];
  final total = clampPercent(courseTotal);
  final anyGraded = clamped.any((i) => i.grade != null);
  final mid = _pick(clamped, _midtermPatterns);
  final end = _pick(clamped, _endtermPatterns, exclude: {?mid});
  final fin = _pick(clamped, _finalPatterns, exclude: {?mid, ?end});
  return LmsCourseData(
    lmsCourseId: base.lmsCourseId,
    title: base.title,
    teacherName: base.teacherName,
    classification: base.classification,
    total: anyGraded ? (total ?? clampPercent(base.total)) : null,
    midterm: mid?.grade,
    endterm: end?.grade,
    finalExam: fin?.grade,
    gradeItemsJson: jsonEncode(clamped.map((i) => i.toJson()).toList()),
  );
}

/// Classifies a Moodle calendar event. [moduleName] may carry the `mod_`
/// prefix (HTML `data-event-component`) or not (AJAX `modulename`).
LmsEventType classifyMoodleEvent({String? moduleName, String? eventType}) {
  final module = (moduleName ?? '').replaceFirst('mod_', '');
  if (module == 'attendance') return LmsEventType.classSession;
  const deadlineTypes = {'due', 'close', 'expectcompletionon'};
  if (deadlineTypes.contains(eventType)) return LmsEventType.deadline;
  return LmsEventType.other;
}

/// Kind of calendar event. Stored in the database as [storageValue].
enum LmsEventType {
  deadline('deadline'),
  classSession('class'),
  other('other');

  const LmsEventType(this.storageValue);

  final String storageValue;

  static LmsEventType fromStorage(String? value) {
    for (final t in values) {
      if (t.storageValue == value) return t;
    }
    return LmsEventType.other;
  }
}

class LmsEventData {
  const LmsEventData({
    this.lmsEventId,
    this.lmsCourseId,
    required this.title,
    this.courseTitle,
    required this.type,
    this.moduleName,
    required this.startsAt,
    this.durationMin,
    this.location,
    this.url,
  });

  final int? lmsEventId;
  final int? lmsCourseId;
  final String title;
  final String? courseTitle;
  final LmsEventType type;

  /// Moodle module name without the `mod_` prefix: `assign`, `quiz`,
  /// `attendance`, … .
  final String? moduleName;

  /// Start of a class, or the due time of a deadline (local time).
  final DateTime startsAt;
  final int? durationMin;
  final String? location;
  final String? url;

  @override
  String toString() =>
      'LmsEventData($lmsEventId, $title, ${type.storageValue}, $startsAt)';
}

class LmsMaterialData {
  const LmsMaterialData({
    this.lmsModuleId,
    this.lmsCourseId,
    this.courseTitle,
    this.sectionTitle,
    required this.title,
    required this.materialType,
    this.url,
  });

  final int? lmsModuleId;
  final int? lmsCourseId;
  final String? courseTitle;
  final String? sectionTitle;
  final String title;

  /// `file` / `folder` / `url` / `page` / `other`.
  final String materialType;
  final String? url;

  @override
  String toString() => 'LmsMaterialData($lmsModuleId, $title, $materialType)';
}

class LmsProfileData {
  const LmsProfileData({required this.fullName, this.email, this.lmsUserId});

  final String fullName;
  final String? email;
  final int? lmsUserId;

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'lmsUserId': lmsUserId,
  };

  factory LmsProfileData.fromJson(Map<String, dynamic> json) => LmsProfileData(
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String?,
    lmsUserId: (json['lmsUserId'] as num?)?.toInt(),
  );
}

/// Everything one import run produced. Each kind is independent: a failed kind
/// leaves its list empty and puts a message under its key in [errors]
/// (`courses`, `grades`, `deadlines`, `classes`, `materials`, `profile`).
class LmsImportResult {
  const LmsImportResult({
    this.courses = const [],
    this.events = const [],
    this.materials = const [],
    this.profile,
    this.errors = const {},
    this.failedGradeCourseIds = const {},
    this.materialCourseIds,
  });

  final List<LmsCourseData> courses;
  final List<LmsEventData> events;
  final List<LmsMaterialData> materials;
  final LmsProfileData? profile;
  final Map<String, String> errors;

  /// Courses whose grade report could not be read (neither AJAX nor HTML).
  /// The importer keeps their stored scores instead of writing `null`.
  final Set<int> failedGradeCourseIds;

  /// Courses whose contents were loaded completely; the importer deletes
  /// missing materials only of these courses. `null` (hand-built results)
  /// means «the courses that appear in [materials]».
  final Set<int>? materialCourseIds;
}

/// Clamps a percent score to 0..100; NaN / infinity → `null`.
double? clampPercent(double? v) {
  if (v == null || !v.isFinite) return null;
  return v.clamp(0, 100).toDouble();
}

/// Converts a raw grade to percent of its range: `(raw - min) / (max - min) *
/// 100` when [max] is known and not 100 (and `max > min`); otherwise [raw] is
/// taken as a percent already. The result is clamped by [clampPercent].
double? gradeToPercent(double? raw, {double? min, double? max}) {
  if (raw == null || !raw.isFinite) return null;
  final lo = (min != null && min.isFinite) ? min : 0.0;
  if (max != null && max.isFinite && max != 100 && max > lo) {
    return clampPercent((raw - lo) / (max - lo) * 100);
  }
  return clampPercent(raw);
}
