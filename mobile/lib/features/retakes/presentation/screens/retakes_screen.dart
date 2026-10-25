import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/models/grade_models.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';

class RetakesScreen extends StatefulWidget {
  const RetakesScreen({super.key});

  @override
  State<RetakesScreen> createState() => _RetakesScreenState();
}

class _RetakesScreenState extends State<RetakesScreen> {
  final _dataService = AituDataService();
  String _activeTab = 'По оценкам'; // 'По оценкам', 'По среднему'

  @override
  void initState() {
    super.initState();
    _dataService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _dataService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _showAddAppointmentDialog(RetakeItem item) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 2));
    TimeOfDay selectedTime = const TimeOfDay(hour: 15, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(
            'Запись на отработку: ${item.subjectName}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Преподаватель: ${item.teacherName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              const Text('Дата отработки:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.accentCyan),
                      const SizedBox(width: 8),
                      Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                          style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Время приёма:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setModalState(() => selectedTime = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: AppColors.accentCyan),
                      const SizedBox(width: 8),
                      Text(selectedTime.format(context), style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                _dataService.updateRetakeStatus(item.id, 'Записан на отработку', item.targetScore);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text('Запись оформлена на ${selectedDate.day}.${selectedDate.month} в ${selectedTime.format(context)}'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Подтвердить запись'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final retakes = _dataService.retakes;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ПЛАН ИСПРАВЛЕНИЙ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
              ),
              SizedBox(height: 2),
              Text(
                'Отработки и хвосты',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'Оценки ниже 51 · локальный трекер студента AITU',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTabButton('По оценкам · ${retakes.length}', _activeTab == 'По оценкам', () {
                setState(() => _activeTab = 'По оценкам');
              }),
              const SizedBox(width: 8),
              _buildTabButton('По среднему', _activeTab == 'По среднему', () {
                setState(() => _activeTab = 'По среднему');
              }),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.plate(AppColors.warning, 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.plate(AppColors.warning, 0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Статусы — ваши личные отметки, они не изменяют базу LMS AITU. «Исправлено» подтверждается источником только после официальной пересдачи преподавателю.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (retakes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success),
                  SizedBox(height: 12),
                  Text(
                    'Задолженностей нет!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Все оценки выше 51 балла.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...retakes.map((item) => _buildRetakeCard(item)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected, VoidCallback onTap) {
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
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRetakeCard(RetakeItem item) {
    final statusList = ['Нужно отработать', 'Записан на отработку', 'На проверке', 'Отработано'];
    final targetScores = [80, 85, 90, 100];

    // simulated prediction:
    final currentScore = item.score;
    final forecastScore = item.targetScore;
    final simulatedAvg = (45.7 - (currentScore * 0.1) + (forecastScore * 0.15)).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.subjectName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Text(
                    item.teacherName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.plate(AppColors.danger, 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Средний: 45.7',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.plate(AppColors.danger, 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.plate(AppColors.danger, 0.4)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${item.score}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.danger),
                    ),
                    const Text('из 100', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Дата: ${item.date}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    const Text('Текущий контроль', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Мой статус', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: item.status,
                          isExpanded: true,
                          dropdownColor: AppColors.elevated,
                          items: statusList.map((st) {
                            return DropdownMenuItem<String>(
                              value: st,
                              child: Text(st, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _dataService.updateRetakeStatus(item.id, val, item.targetScore);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Прогноз замены', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: item.targetScore,
                          isExpanded: true,
                          dropdownColor: AppColors.elevated,
                          items: targetScores.map((score) {
                            return DropdownMenuItem<int>(
                              value: score,
                              child: Text('$score / 100', style: const TextStyle(fontSize: 12, color: AppColors.accentCyan)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _dataService.updateRetakeStatus(item.id, item.status, val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Прогноз среднего: 45.7 → $simulatedAvg',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddAppointmentDialog(item),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: const Text('Записаться к преподавателю'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accentCyan),
                foregroundColor: AppColors.accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
