class AcademicEvent {
  final String id;
  final String title;
  final String category; // 'Учёба', 'Контроль', 'Сессия', 'Каникулы', 'Праздники', 'Практика'
  final String dates;
  final String year;
  final bool isCurrent;
  final String description;
  final String course;

  const AcademicEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.dates,
    required this.year,
    this.isCurrent = false,
    required this.description,
    this.course = 'Все курсы',
  });
}
