import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';

class AdminPanelScreen extends StatefulWidget {
  final String userRole;
  final String groupTitle;

  const AdminPanelScreen({
    super.key,
    required this.userRole,
    required this.groupTitle,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _dataService = AituDataService();
  String _activeTab = 'Расписание'; // 'Расписание', 'Ведомость', 'ДЗ группы'

  void _announceScheduleChange() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
        title: const Text('Объявить изменение расписания', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Сообщение будет отправлено всем студентам группы и закреплено в общем чате:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Например: Лабораторная по Базам данных переносится в C1.2.245 на 14:00',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text('Уведомление об изменении расписания опубликовано в чате группы'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Опубликовать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHeadman = widget.userRole == 'headman';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'УПРАВЛЕНИЕ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Администрирование',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Панель старосты · Группа ${_dataService.currentGroup}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isHeadman ? AppColors.plate(AppColors.accent, 0.2) : AppColors.plate(AppColors.accentCyan, 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isHeadman ? AppColors.accent : AppColors.accentCyan),
                ),
                child: Text(
                  isHeadman ? 'Староста группы' : 'Студент',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isHeadman ? AppColors.accent : AppColors.accentCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStatsOverview(),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildTab('Расписание', _activeTab == 'Расписание', () => setState(() => _activeTab = 'Расписание')),
              const SizedBox(width: 8),
              _buildTab('Ведомость', _activeTab == 'Ведомость', () => setState(() => _activeTab = 'Ведомость')),
              const SizedBox(width: 8),
              _buildTab('ДЗ группы', _activeTab == 'ДЗ группы', () => setState(() => _activeTab = 'ДЗ группы')),
            ],
          ),
          const SizedBox(height: 16),
          if (_activeTab == 'Расписание') ...[
            ElevatedButton.icon(
              onPressed: _announceScheduleChange,
              icon: const Icon(Icons.campaign_rounded, size: 18),
              label: const Text('Объявить перенос или отмену пары'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            _buildScheduleAdminItem('Calculus 1', 'Кафедра высшей математики', '08:30', 'Ауд. C1.2.204', 'Штатно'),
            _buildScheduleAdminItem('Introduction to Programming', 'Кафедра Computer Science', '10:05', 'Лаб. C1.1.105', 'Контроль'),
            _buildScheduleAdminItem('Information & Comm. Technologies', 'Кафедра ICT', '11:40', 'Mac Lab C1.3', 'Штатно'),
          ] else if (_activeTab == 'Ведомость') ...[
            _buildStudentGradeItem('Студент 1 (ID: 260101)', '92.4', 'Отличник (Повышка)', AppColors.success),
            _buildStudentGradeItem('Студент 2 (ID: 260102)', '88.1', 'Хорошист (Обычная)', AppColors.accentCyan),
            _buildStudentGradeItem('Студент 3 (ID: 260103)', '95.0', 'Отличник (Повышка)', AppColors.success),
            _buildStudentGradeItem('Студент 4 (ID: 260104)', '48.2', 'Имеет отработку (Discrete Math)', AppColors.warning),
            _buildStudentGradeItem('Студент 5 (ID: 260105)', '79.5', 'Хорошист (Обычная)', AppColors.accentCyan),
          ] else ...[
            _buildGroupHomeworkItem('Introduction to Programming', 'Лабораторная №4: Рекурсия и структуры данных', 'Срок: 15 ноября'),
            _buildGroupHomeworkItem('Information & Comm. Technologies', 'Лабораторная №3: Сети и протоколы', 'Срок: 20 ноября'),
          ],
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.accentCyan : AppColors.border),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
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
          const Text('Показатели успеваемости группы', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Студентов', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const Text('28', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Средний GPA', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const Text('3.42 / 4.0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accentCyan)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Повышка', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const Text('6 чел.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleAdminItem(String subject, String teacher, String time, String room, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('$time • $room • $teacher', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status, style: const TextStyle(fontSize: 11, color: AppColors.accentCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGradeItem(String name, String score, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.plate(color, 0.2),
            child: Text(name[0], style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(status, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
          Text(score, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildGroupHomeworkItem(String subject, String task, String deadline) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subject, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentCyan)),
              Text(deadline, style: const TextStyle(fontSize: 11, color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 4),
          Text(task, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
