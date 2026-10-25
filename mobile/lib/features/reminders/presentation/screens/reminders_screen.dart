import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:studyplan/core/services/ics_export_service.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _dataService = AituDataService();
  bool _pairsReminder = true;
  bool _homeworkReminder = true;
  bool _retakesReminder = true;

  final List<Map<String, String>> _customReminders = [
    {
      'title': 'Сдать конспект по Discrete Math (отработка)',
      'time': 'Завтра, 15:00',
      'type': 'Отработка',
    },
    {
      'title': 'Подготовка к Midterm по Calculus 1',
      'time': '17 ноября, 09:00',
      'type': 'Контроль',
    },
  ];

  void _exportIcs() {
    final group = _dataService.currentGroup;
    final mockLessons = [
      {'title': 'Calculus 1', 'classroom': 'Ауд. C1.2.204', 'teacher': 'Кафедра высшей математики', 'startTime': '08:30', 'endTime': '09:50', 'dayOfWeek': 1},
      {'title': 'Introduction to Programming', 'classroom': 'Лаб. C1.1.105', 'teacher': 'Кафедра Computer Science', 'startTime': '10:05', 'endTime': '11:25', 'dayOfWeek': 1},
      {'title': 'Information & Comm. Technologies', 'classroom': 'Mac Lab C1.3', 'teacher': 'Кафедра ICT', 'startTime': '11:40', 'endTime': '13:00', 'dayOfWeek': 2},
      {'title': 'Foreign Language', 'classroom': 'Ауд. C1.2.118', 'teacher': 'Языковой центр', 'startTime': '08:30', 'endTime': '09:50', 'dayOfWeek': 3},
      {'title': 'History of Kazakhstan', 'classroom': 'Ауд. C1.1.220', 'teacher': 'Кафедра гуманитарных наук', 'startTime': '10:05', 'endTime': '11:25', 'dayOfWeek': 4},
    ];

    final icsContent = IcsExportService.generateUniversityCalendarIcs(
      groupName: group,
      lessons: mockLessons,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppColors.accentCyan, size: 22),
            const SizedBox(width: 8),
            Text('Календарь .ICS ($group)', style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Файл календаря iCalendar (.ics) успешно сгенерирован для вашей группы. Вы можете импортировать его в Apple Calendar, Google Calendar или Outlook:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  icsContent,
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: icsContent));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Текст .ICS скопирован в буфер обмена')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Скопировать'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // ignore: deprecated_member_use
              Share.share(icsContent, subject: 'Astana IT University Расписание ($group).ics');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan),
            icon: const Icon(Icons.share_rounded, size: 16, color: Colors.black),
            label: const Text('Поделиться файлом', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _addCustomReminder() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Новое напоминание', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
        content: TextField(
          controller: titleController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Что нужно сделать...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                setState(() {
                  _customReminders.add({
                    'title': titleController.text.trim(),
                    'time': 'Сегодня, 18:00',
                    'type': 'Личное',
                  });
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Сохранить'),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'НИЧЕГО НЕ ПРОПУСТИТЬ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
              ),
              SizedBox(height: 2),
              Text(
                'Напоминания',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              SizedBox(height: 2),
              Text(
                'Время Астаны · Asia/Almaty · UTC+5',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPhoneNotificationsCard(),
          const SizedBox(height: 16),
          _buildCalendarExportCard(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Мои персональные напоминания',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              IconButton(
                onPressed: _addCustomReminder,
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentCyan),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._customReminders.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.accentCyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['title']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('${r['time']} • ${r['type']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPhoneNotificationsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.plate(AppColors.accentCyan, 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.accentCyan, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Уведомления на телефон', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('О начале и конце пар, а в 14:30 — список ДЗ на сегодня.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _pairsReminder,
            onChanged: (v) => setState(() => _pairsReminder = v ?? false),
            title: const Text('Начало и конец пар', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: Text('По расписанию группы ${_dataService.currentGroup} · понедельник — суббота',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            activeColor: AppColors.accentCyan,
            checkColor: Colors.black,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(color: AppColors.border, height: 1),
          CheckboxListTile(
            value: _homeworkReminder,
            onChanged: (v) => setState(() => _homeworkReminder = v ?? false),
            title: const Text('Домашнее задание', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: const Text('Каждый учебный день в 14:30', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            activeColor: AppColors.accentCyan,
            checkColor: Colors.black,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(color: AppColors.border, height: 1),
          CheckboxListTile(
            value: _retakesReminder,
            onChanged: (v) => setState(() => _retakesReminder = v ?? false),
            title: const Text('Отработки и рубежные контроли', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: const Text('Напоминание за 24 часа и за 2 часа до дедлайна', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            activeColor: AppColors.accentCyan,
            checkColor: Colors.black,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Настройки push-уведомлений сохранены в системе')),
                );
              },
              icon: const Icon(Icons.notifications_active_rounded, size: 16),
              label: const Text('Включить уведомления'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarExportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.download_rounded, size: 20, color: AppColors.accentCyan),
              SizedBox(width: 10),
              Text('В календарь телефона', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Сохраните весь учебный семестр группы ${_dataService.currentGroup}: пары, кабинеты, преподавателей и отметки ДЗ.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportIcs,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: const Text('Скачать календарь .ics'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accentCyan),
                foregroundColor: AppColors.accentCyan,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
