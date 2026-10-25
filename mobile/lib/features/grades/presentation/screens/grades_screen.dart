import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/models/grade_models.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';

class GradesScreen extends StatefulWidget {
  final VoidCallback? onOpenSimulator;

  const GradesScreen({super.key, this.onOpenSimulator});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final _dataService = AituDataService();
  String _searchQuery = '';
  String _activeFilter = 'Все'; // 'Все', 'Отработки', 'Отличные', 'Спорные'
  bool _useFivePointScale = false;

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

  List<SubjectGrade> _getFilteredSubjects() {
    var list = _dataService.subjects;
    if (_searchQuery.isNotEmpty) {
      list = list.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    switch (_activeFilter) {
      case 'Отработки':
        return list.where((s) => s.average < 51 || s.retakesCount > 0).toList();
      case 'Отличные':
        return list.where((s) => s.average >= 90).toList();
      case 'Спорные':
        return list.where((s) => s.average >= 85 && s.average < 90).toList();
      default:
        return list;
    }
  }

  void _showAddVirtualGradeDialog(SubjectGrade subject) {
    int score = 85;
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
            'Оценка для «${subject.name}»',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Добавьте виртуальную оценку, чтобы проверить влияние на средний балл и повышенную стипендию:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: score >= 90
                        ? AppColors.success
                        : score >= 75
                            ? AppColors.accentCyan
                            : score >= 51
                                ? AppColors.warning
                                : AppColors.danger,
                  ),
                ),
              ),
              Slider(
                value: score.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: AppColors.accentCyan,
                onChanged: (val) {
                  setModalState(() {
                    score = val.round();
                  });
                },
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
                _dataService.addVirtualGrade(subject.id, score);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text('Виртуальная оценка $score добавлена к «${subject.name}»'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan),
              child: const Text('Добавить в симуляцию', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredSubjects();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 18),
          _buildSearchAndFilters(),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
                  SizedBox(height: 10),
                  Text('Предметы не найдены', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            ...filtered.map((s) => _buildSubjectCard(s)),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ЛИЧНЫЙ ЖУРНАЛ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
            ),
            const SizedBox(height: 2),
            const Text(
              'Оценки и успеваемость',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              'Группа ${_dataService.currentGroup} · LMS AITU',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final avg = _dataService.overallAverage;
    final excellent = _dataService.excellentCount;
    final retakes = _dataService.retakesSubjectsCount;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Общий средний', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$avg',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accentCyan),
                    ),
                    const Text(' /100', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('Среднее по предметам', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('На «Отлично»', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$excellent',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.success),
                    ),
                    Text(' /${_dataService.subjects.length}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('Баллы от 90 и выше', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Отработки', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  '$retakes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: retakes > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Ниже 51 балла', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  hintText: 'Найти предмет...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accentCyan),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildScaleButton('100', !_useFivePointScale),
                  _buildScaleButton('5 б.', _useFivePointScale),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Все', 'Отработки', 'Отличные', 'Спорные'].map((f) {
              final isSel = _activeFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(f),
                  selected: isSel,
                  onSelected: (_) => setState(() => _activeFilter = f),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.black : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.accentCyan,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: isSel ? AppColors.accentCyan : AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildScaleButton(String label, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _useFivePointScale = label == '5 б.'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(SubjectGrade subject) {
    final statusColor = subject.average >= 90
        ? AppColors.success
        : subject.average >= 75
            ? AppColors.accentCyan
            : subject.average >= 51
                ? AppColors.warning
                : AppColors.danger;

    final displayScore = _useFivePointScale ? subject.gpaLetter : '${subject.average}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: subject.hasWarning ? AppColors.plate(AppColors.danger, 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subject.teacher,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.plate(statusColor, 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.plate(statusColor, 0.4)),
                ),
                child: Text(
                  subject.statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...subject.grades.map((g) {
                  final chipColor = g.score >= 90
                      ? AppColors.success
                      : g.score >= 75
                          ? AppColors.accentCyan
                          : g.score >= 51
                              ? AppColors.warning
                              : AppColors.danger;

                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: g.isVirtual ? AppColors.plate(AppColors.accent, 0.25) : AppColors.elevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: g.isVirtual ? AppColors.accent : AppColors.border,
                        width: g.isVirtual ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${g.score}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: g.isVirtual ? AppColors.accent : chipColor,
                          ),
                        ),
                        Text(
                          g.date,
                          style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }),
                IconButton(
                  onPressed: () => _showAddVirtualGradeDialog(subject),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: AppColors.accentCyan),
                  tooltip: 'Добавить прогноз',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Средний балл: $displayScore',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              if (widget.onOpenSimulator != null)
                TextButton(
                  onPressed: widget.onOpenSimulator,
                  child: const Text('Смоделировать в «А что, если?» →', style: TextStyle(fontSize: 11, color: AppColors.accentCyan)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
