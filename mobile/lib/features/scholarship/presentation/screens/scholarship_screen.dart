import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/grades/data/services/aitu_data_service.dart';

class ScholarshipScreen extends StatefulWidget {
  final VoidCallback? onOpenSimulator;

  const ScholarshipScreen({super.key, this.onOpenSimulator});

  @override
  State<ScholarshipScreen> createState() => _ScholarshipScreenState();
}

class _ScholarshipScreenState extends State<ScholarshipScreen> {
  final _dataService = AituDataService();

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

  @override
  Widget build(BuildContext context) {
    final subjects = _dataService.subjects;
    final below90 = subjects.where((s) => s.average < 90).toList();
    final below70 = subjects.where((s) => s.average < 70).toList();
    final isHonorsEligible = below90.isEmpty && subjects.isNotEmpty;
    final isRegularEligible = below70.isEmpty && subjects.isNotEmpty;

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
                    'ПЛАН ПО ОЦЕНКАМ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.accentCyan),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Повышенная стипендия',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Порог по каждому предмету: 90 / 100',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (widget.onOpenSimulator != null)
                ElevatedButton.icon(
                  onPressed: widget.onOpenSimulator,
                  icon: const Icon(Icons.science_outlined, size: 16),
                  label: const Text('Симулятор', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.elevated,
                    foregroundColor: AppColors.accentCyan,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStatusCards(isRegularEligible, isHonorsEligible, below90.length),
          const SizedBox(height: 18),
          _buildCriteriaCard(),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'План повышения до 90+',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.plate(AppColors.warning, 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${below90.length} предм. требуют внимания',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (below90.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success),
              ),
              child: const Column(
                children: [
                  Icon(Icons.emoji_events_rounded, size: 48, color: AppColors.success),
                  SizedBox(height: 10),
                  Text(
                    'Отличный результат!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Все предметы закрыты на 90 и выше. Вы претендуете на повышенную стипендию 50 110 ₸!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...below90.map((s) => _buildTargetSubjectCard(s)),
        ],
      ),
    );
  }

  Widget _buildStatusCards(bool regular, bool honors, int below90Count) {
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
                const Text('Обычная · от 70', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  regular ? 'Выполняется' : 'Есть пробелы',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: regular ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('43 574 ₸ / мес.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
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
                const Text('Повышенная · от 90', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  honors ? 'Достигнуто!' : 'В процессе',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: honors ? AppColors.success : AppColors.accentCyan,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('50 110 ₸ (+15%)', style: TextStyle(fontSize: 10, color: AppColors.accentCyan)),
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
                const Text('С учётом симуляции', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  '$below90Count ниже',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: below90Count == 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('требуют добора', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCriteriaCard() {
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
            'Условия расчёта',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          _buildCheckRow(Icons.check_rounded, AppColors.success, 'Средний по каждому предмету не ниже 90'),
          const SizedBox(height: 6),
          _buildCheckRow(Icons.check_rounded, AppColors.success, 'По всем предметам выставлены оценки · без оценок: 0'),
          const SizedBox(height: 6),
          _buildCheckRow(Icons.school_outlined, AppColors.accentCyan, 'Официальные итоговые баллы и право на стипендию утверждает Astana IT University'),
          const SizedBox(height: 12),
          const Text(
            'Это прогноз по текущим средним показателям LMS AITU. Наличие одного очень высокого балла (например, 98) не компенсирует оценку ниже порога по другому предмету — стипендия отличника требует 90+ во всех дисциплинах.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildTargetSubjectCard(dynamic subject) {
    final double diff = double.parse((90.0 - subject.average).toStringAsFixed(1));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.plate(diff > 20 ? AppColors.danger : AppColors.warning, 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${subject.average}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: diff > 20 ? AppColors.danger : AppColors.warning,
                  ),
                ),
                const Text('тек. балл', style: TextStyle(fontSize: 8, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Преподаватель: ${subject.teacher}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Нужно набрать ещё: +$diff баллов для порога 90',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
