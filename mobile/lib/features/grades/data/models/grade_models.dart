class SubjectGrade {
  final String id;
  final String name;
  final String teacher;
  final double average;
  final List<LessonGrade> grades;
  final int retakesCount;
  final bool hasWarning;

  const SubjectGrade({
    required this.id,
    required this.name,
    required this.teacher,
    required this.average,
    required this.grades,
    this.retakesCount = 0,
    this.hasWarning = false,
  });

  String get statusText {
    if (average >= 90) return 'Отлично';
    if (average >= 75) return 'Хорошо';
    if (average >= 51) return 'Удовл.';
    return 'Нужна отработка';
  }

  String get gpaLetter {
    if (average >= 95) return 'A';
    if (average >= 90) return 'A-';
    if (average >= 85) return 'B+';
    if (average >= 80) return 'B';
    if (average >= 75) return 'B-';
    if (average >= 70) return 'C+';
    if (average >= 65) return 'C';
    if (average >= 60) return 'C-';
    if (average >= 55) return 'D+';
    if (average >= 50) return 'D';
    return 'F';
  }

  double get gpa4 {
    if (average >= 95) return 4.0;
    if (average >= 90) return 3.67;
    if (average >= 85) return 3.33;
    if (average >= 80) return 3.0;
    if (average >= 75) return 2.67;
    if (average >= 70) return 2.33;
    if (average >= 65) return 2.0;
    if (average >= 60) return 1.67;
    if (average >= 55) return 1.33;
    if (average >= 50) return 1.0;
    return 0.0;
  }
}

class LessonGrade {
  final String id;
  final int score;
  final String date;
  final String type;
  final bool isVirtual;

  const LessonGrade({
    required this.id,
    required this.score,
    required this.date,
    this.type = 'Текущий контроль',
    this.isVirtual = false,
  });
}

class RetakeItem {
  final String id;
  final String subjectName;
  final String teacherName;
  final int score;
  final String date;
  String status; // 'Нужно отработать', 'Записан', 'На проверке', 'Отработано'
  int targetScore;

  RetakeItem({
    required this.id,
    required this.subjectName,
    required this.teacherName,
    required this.score,
    required this.date,
    this.status = 'Нужно отработать',
    this.targetScore = 80,
  });
}
