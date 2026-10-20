import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/tasks/presentation/widgets/task_detail_bottom_sheet.dart';

class ScheduleCalendarScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  const ScheduleCalendarScreen({
    super.key,
    required this.db,
    required this.userId,
  });

  @override
  State<ScheduleCalendarScreen> createState() => _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState extends State<ScheduleCalendarScreen> {
  int _selectedDay = DateTime.now().weekday;
  bool? _filterEvenWeek; // null = all, true = even, false = odd

  final _days = const [
    (1, 'Понедельник'),
    (2, 'Вторник'),
    (3, 'Среда'),
    (4, 'Четверг'),
    (5, 'Пятница'),
    (6, 'Суббота'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Parity bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Text('Неделя:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Все'),
                selected: _filterEvenWeek == null,
                onSelected: (_) => setState(() => _filterEvenWeek = null),
                backgroundColor: AppColors.elevated,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _filterEvenWeek == null ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Числитель (1)'),
                selected: _filterEvenWeek == false,
                onSelected: (_) => setState(() => _filterEvenWeek = false),
                backgroundColor: AppColors.elevated,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _filterEvenWeek == false ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Знаменатель (2)'),
                selected: _filterEvenWeek == true,
                onSelected: (_) => setState(() => _filterEvenWeek = true),
                backgroundColor: AppColors.elevated,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _filterEvenWeek == true ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Day selector tabs
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = _days[index];
              final isSelected = day.$1 == _selectedDay;

              return ChoiceChip(
                label: Text(day.$2),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedDay = day.$1),
                backgroundColor: AppColors.elevated,
                selectedColor: AppColors.accentCyan,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.border, height: 1),
        // List of lessons for the selected day
        Expanded(
          child: StreamBuilder<List<Lesson>>(
            stream: (widget.db.select(widget.db.lessons)
                  ..where((t) =>
                      t.userId.equals(widget.userId) &
                      t.dayOfWeek.equals(_selectedDay) &
                      t.isDeleted.equals(false))
                  ..orderBy([(t) => drift.OrderingTerm.asc(t.startTime)]))
                .watch(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }

              final all = snapshot.data ?? [];
              final filtered = all.where((l) {
                if (_filterEvenWeek != null && l.isEvenWeek != null && l.isEvenWeek != _filterEvenWeek) {
                  return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'На этот день пар нет',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final lesson = filtered[index];
                  final color = AppColors.lessonType(lesson.lessonType);

                  return StreamBuilder<Subject?>(
                    stream: (widget.db.select(widget.db.subjects)
                          ..where((t) => t.id.equals(lesson.subjectId)))
                        .watchSingleOrNull(),
                    builder: (context, subSnap) {
                      final title = subSnap.data?.title ?? 'Занятие';
                      final teacher = subSnap.data?.teacherName ?? '';

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          TaskDetailBottomSheet.show(
                            context,
                            db: widget.db,
                            userId: widget.userId,
                            initialSubjectId: lesson.subjectId,
                            initialSubjectTitle: title,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${lesson.startTime} – ${lesson.endTime}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.accentCyan,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            if (lesson.classroom != null) ...[
                                              Text(
                                                lesson.classroom!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            const Icon(Icons.add_task_rounded, size: 16, color: AppColors.accentCyan),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (teacher.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        teacher,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
