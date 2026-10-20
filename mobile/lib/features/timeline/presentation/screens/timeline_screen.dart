import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/utils/date_util.dart';
import 'package:studyplan/features/tasks/presentation/widgets/task_detail_bottom_sheet.dart';

class TimelineScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  const TimelineScreen({
    super.key,
    required this.db,
    required this.userId,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Column(
      children: [
        _buildWeekScroller(weekDays),
        const Divider(color: AppColors.border, height: 1),
        Expanded(
          child: StreamBuilder<List<Lesson>>(
            stream: (widget.db.select(widget.db.lessons)
                  ..where((t) =>
                      t.userId.equals(widget.userId) &
                      t.dayOfWeek.equals(_selectedDate.weekday) &
                      t.isDeleted.equals(false))
                  ..orderBy([(t) => drift.OrderingTerm.asc(t.startTime)]))
                .watch(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }

              final allLessons = snapshot.data ?? [];
              final isEven = DateUtil.isEvenWeek(_selectedDate);

              // Filter out lessons with week parity mismatch
              final dayLessons = allLessons.where((l) {
                if (l.isEvenWeek != null && l.isEvenWeek != isEven) {
                  return false;
                }
                return true;
              }).toList();

              if (dayLessons.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available_outlined, size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'Пар нет — свободный день!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Отличное время закрыть дедлайны',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: dayLessons.length,
                itemBuilder: (context, index) {
                  final lesson = dayLessons[index];
                  return _buildLessonTimelineItem(context, lesson);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekScroller(List<DateTime> days) {
    final ruDayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((day) {
          final isSelected = day.year == _selectedDate.year &&
              day.month == _selectedDate.month &&
              day.day == _selectedDate.day;
          final isToday = day.year == DateTime.now().year &&
              day.month == DateTime.now().month &&
              day.day == DateTime.now().day;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _selectedDate = day;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : (isToday ? AppColors.elevated : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.accent : (isToday ? AppColors.accentCyan : Colors.transparent),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    ruDayNames[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLessonTimelineItem(BuildContext context, Lesson lesson) {
    final typeColor = AppColors.lessonType(lesson.lessonType);
    final typeLabel = switch (lesson.lessonType) {
      'practice' => 'Практика',
      'lab' => 'Лабораторная',
      _ => 'Лекция',
    };

    return StreamBuilder<Subject?>(
      stream: (widget.db.select(widget.db.subjects)..where((t) => t.id.equals(lesson.subjectId)))
          .watchSingleOrNull(),
      builder: (context, subjectSnap) {
        final subjectTitle = subjectSnap.data?.title ?? 'Занятие';
        final teacherName = subjectSnap.data?.teacherName ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lesson.startTime,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.endTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 80,
                    color: AppColors.border,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    TaskDetailBottomSheet.show(
                      context,
                      db: widget.db,
                      userId: widget.userId,
                      initialSubjectId: lesson.subjectId,
                      initialSubjectTitle: subjectTitle,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.plate(typeColor),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                if (lesson.classroom != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.elevated,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border, width: 1),
                                    ),
                                    child: Text(
                                      lesson.classroom!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                const Icon(Icons.add_task_rounded, size: 16, color: AppColors.accentCyan),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subjectTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (lesson.topic != null && lesson.topic!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            lesson.topic!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (teacherName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                teacherName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
