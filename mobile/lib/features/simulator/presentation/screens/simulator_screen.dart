import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/models/grade_models.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final _dataService = AituDataService();
  String? _selectedSubjectId;
  int _virtualScore = 95;

  @override
  void initState() {
    super.initState();
    _dataService.addListener(_onDataChanged);
    if (_dataService.subjects.isNotEmpty) {
      _selectedSubjectId = _dataService.subjects.first.id;
    }
  }

  @override
  void dispose() {
    _dataService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _applyVirtualScore() {
    if (_selectedSubjectId == null) return;
    _dataService.addVirtualGrade(_selectedSubjectId!, _virtualScore);

    final subj = _dataService.subjects.firstWhere((s) => s.id == _selectedSubjectId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Прогноз $_virtualScore добавлен к «${subj.name}». Новый средний: ${subj.average}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _dataService.subjects;
    final avg = _dataService.overallAverage;
    final below90 = subjects.where((s) => s.average < 90).length;
    final hasVirtual = subjects.any((s) => s.grades.any((g) => g.isVirtual));

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
                    'ЛОКАЛЬНЫЙ ПРОГНОЗ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'А что, если?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
              if (hasVirtual)
                TextButton.icon(
                  onPressed: () {
                    _dataService.clearVirtualGrades();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Все виртуальные оценки сброшены')),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.warning),
                  label: const Text('Сбросить', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Добавьте виртуальную оценку и посмотрите на результат среднего балла и шанс на повышенную стипендию.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          _buildSimulatorInputCard(subjects),
          const SizedBox(height: 18),
          _buildImpactSummary(avg, below90),
          const SizedBox(height: 18),
          const Text(
            'Состояние предметов после симуляции',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ...subjects.map((s) => _buildSimulatedSubjectItem(s)),
        ],
      ),
    );
  }

  Widget _buildSimulatorInputCard(List<SubjectGrade> subjects) {
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
          const Text(
            'Выберите предмет для проверки:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSubjectId,
                isExpanded: true,
                dropdownColor: AppColors.elevated,
                items: subjects.map((s) {
                  return DropdownMenuItem<String>(
                    value: s.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                        Text('Текущий: ${s.average}', style: const TextStyle(fontSize: 11, color: AppColors.accentCyan)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSubjectId = val),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Виртуальная оценка:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.plate(AppColors.accentCyan, 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_virtualScore / 100',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accentCyan),
                ),
              ),
            ],
          ),
          Slider(
            value: _virtualScore.toDouble(),
            min: 50,
            max: 100,
            divisions: 50,
            activeColor: AppColors.accentCyan,
            inactiveColor: AppColors.border,
            onChanged: (val) => setState(() => _virtualScore = val.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [80, 85, 90, 95, 100].map((score) {
              final isCur = _virtualScore == score;
              return InkWell(
                onTap: () => setState(() => _virtualScore = score),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCur ? AppColors.accentCyan : AppColors.elevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCur ? Colors.black : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applyVirtualScore,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Применить оценку в симуляции'),
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

  Widget _buildImpactSummary(double avg, int below90) {
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
              Icon(Icons.assessment_outlined, size: 18, color: AppColors.accentCyan),
              SizedBox(width: 8),
              Text(
                'Прогноз результатов',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Общий средний балл', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '$avg / 100',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.accentCyan),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Предметов ниже 90', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      '$below90',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: below90 == 0 ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  below90 == 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: below90 == 0 ? AppColors.success : AppColors.accentCyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    below90 == 0
                        ? 'Поздравляем! Все предметы выше 90 — вы проходите на повышенную стипендию (+15%)!'
                        : 'Для повышенной стипендии необходимо подтянуть ещё $below90 предм. выше 90 баллов.',
                    style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedSubjectItem(SubjectGrade subject) {
    final virtualGrades = subject.grades.where((g) => g.isVirtual).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: virtualGrades.isNotEmpty ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                if (virtualGrades.isNotEmpty)
                  Text(
                    'Добавлены прогнозные оценки: ${virtualGrades.map((g) => g.score).join(', ')}',
                    style: const TextStyle(fontSize: 10, color: AppColors.accent),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${subject.average}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: subject.average >= 90
                      ? AppColors.success
                      : subject.average >= 75
                          ? AppColors.accentCyan
                          : AppColors.danger,
                ),
              ),
              Text(
                subject.statusText,
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
