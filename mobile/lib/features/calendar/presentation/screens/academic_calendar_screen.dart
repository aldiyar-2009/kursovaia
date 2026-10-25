import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/calendar/data/models/academic_event.dart';

class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  String _selectedCourse = 'I курс';

  static const List<AcademicEvent> _events = [
    AcademicEvent(
      id: 'cal_1',
      title: 'I семестр',
      category: 'Учёба',
      dates: '1 сентября — 15 февраля',
      year: '2026 / 2027',
      isCurrent: true,
      description: 'Теоретическое и практическое обучение в первом семестре.',
    ),
    AcademicEvent(
      id: 'cal_2',
      title: '1 рубежная неделя',
      category: 'Контроль',
      dates: '17 ноября — 23 ноября',
      year: '2026',
      description: 'Сдача первых рубежных контрольных работ и лабораторных отчетов (РК1).',
    ),
    AcademicEvent(
      id: 'cal_3',
      title: '2 рубежная неделя',
      category: 'Контроль',
      dates: '2 февраля — 8 февраля',
      year: '2027',
      description: 'Второй рубежный контроль (РК2), выставление допуска к зимней сессии.',
    ),
    AcademicEvent(
      id: 'cal_4',
      title: 'Зачетная неделя и экзамены',
      category: 'Сессия',
      dates: '9 февраля — 15 февраля',
      year: '2027',
      description: 'Зимняя экзаменационная сессия за 1-й семестр.',
    ),
    AcademicEvent(
      id: 'cal_5',
      title: 'Зимние каникулы',
      category: 'Каникулы',
      dates: '16 февраля — 28 февраля',
      year: '2027',
      description: 'Официальные зимние студенческие каникулы.',
    ),
    AcademicEvent(
      id: 'cal_6',
      title: 'II семестр',
      category: 'Учёба',
      dates: '1 марта — 30 июня',
      year: '2027',
      description: 'Весенний учебный семестр.',
    ),
    AcademicEvent(
      id: 'cal_7',
      title: 'Наурыз мейрамы и праздничные дни',
      category: 'Праздники',
      dates: '21 марта — 25 марта',
      year: '2027',
      description: 'Государственные весенние праздники Республики Казахстан.',
    ),
    AcademicEvent(
      id: 'cal_8',
      title: '3 рубежная неделя',
      category: 'Контроль',
      dates: '13 апреля — 19 апреля',
      year: '2027',
      description: 'Рубежный контроль РК3 по весенним дисциплинам.',
    ),
    AcademicEvent(
      id: 'cal_9',
      title: '4 рубежная неделя',
      category: 'Контроль',
      dates: '1 июня — 7 июня',
      year: '2027',
      description: 'Итоговый допуск к летней экзаменационной сессии (РК4).',
    ),
    AcademicEvent(
      id: 'cal_10',
      title: 'Летняя экзаменационная сессия',
      category: 'Сессия',
      dates: '8 июня — 20 июня',
      year: '2027',
      description: 'Летние сессионные экзамены и защита курсовых проектов.',
    ),
    AcademicEvent(
      id: 'cal_11',
      title: 'Производственная практика',
      category: 'Практика',
      dates: '22 июня — 5 июля',
      year: '2027',
      description: 'Учебная и профессиональная практика в IT-компаниях Астаны.',
    ),
    AcademicEvent(
      id: 'cal_12',
      title: 'Летние каникулы',
      category: 'Каникулы',
      dates: 'с 6 июля',
      year: '2027',
      description: 'Летний отдых до начала нового 2027-2028 учебного года.',
    ),
  ];

  Color _categoryColor(String category) {
    switch (category) {
      case 'Учёба':
        return AppColors.accentCyan;
      case 'Контроль':
        return AppColors.warning;
      case 'Сессия':
        return AppColors.accent;
      case 'Каникулы':
        return AppColors.success;
      case 'Праздники':
        return const Color(0xFFEC4899);
      case 'Практика':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.textSecondary;
    }
  }

  void _showPdfInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 10),
            Text('Учебный график PDF', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
          ],
        ),
        content: const Text(
          'Официальный утверждённый академический календарь Astana IT University на 2026–2027 учебный год доступен для загрузки в деканате и синхронизирован в офлайн-памяти приложения.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2026 — 2027',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Учебный календарь',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Семестры, сессии и каникулы',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showPdfInfo,
                icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.textPrimary),
                label: const Text('PDF', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Курс / программа',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourse,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                items: ['I курс', 'II курс', 'III курс'].map((course) {
                  return DropdownMenuItem<String>(
                    value: course,
                    child: Text(course, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCourse = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemCount: _events.length,
            itemBuilder: (context, idx) {
              final ev = _events[idx];
              final catColor = _categoryColor(ev.category);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ev.isCurrent ? AppColors.accentCyan : AppColors.border,
                    width: ev.isCurrent ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ev.category,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor),
                        ),
                        if (ev.isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.plate(AppColors.accentCyan, 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Сейчас',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ev.dates,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      ev.year,
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
