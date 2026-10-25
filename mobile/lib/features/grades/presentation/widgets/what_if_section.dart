import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/domain/grading_rules.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';

/// «Что будет, если…»: a hypothetical final exam score for a course whose
/// final is not graded yet. Nothing here is persisted.
class WhatIfSection extends StatefulWidget {
  final LmsCourse course;

  /// Courses of the same semester as [course] (including it), used for the
  /// hypothetical semester GPA and scholarship; null hides those rows.
  final List<LmsCourse>? semester;

  const WhatIfSection({super.key, required this.course, this.semester});

  @override
  State<WhatIfSection> createState() => _WhatIfSectionState();
}

class _WhatIfSectionState extends State<WhatIfSection> {
  late double _final;
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    // Start at the score needed to pass, so the first thing shown is useful.
    final needed = requiredFinal(scoresOf(widget.course), kPassThreshold);
    final start = needed == null
        ? kPassThreshold
        : needed.clamp(kPassThreshold, kMaxScore).toDouble();
    _final = start.ceilToDouble();
    _field = TextEditingController(text: _final.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _setFromSlider(double v) {
    setState(() => _final = v.roundToDouble());
    _field.text = _final.toStringAsFixed(0);
  }

  void _setFromField(String raw) {
    final v = parseScore(raw);
    if (v == null || v < 0 || v > kMaxScore) return;
    setState(() => _final = v);
  }

  CourseScores _withFinal(LmsCourse c) {
    final s = scoresOf(c);
    if (c.id != widget.course.id) return s;
    return CourseScores(
      midterm: s.midterm,
      endterm: s.endterm,
      finalExam: _final,
      lmsTotal: s.lmsTotal,
      credits: s.credits,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final scores = _withFinal(widget.course);
    final total = courseTotal(scores);
    final status = courseStatusLabel(l10n, statusFor(scores));
    final semester = widget.semester?.map(_withFinal).toList();
    final semesterGpa = semester == null ? null : gpa(semester);
    final scholarship =
        semester == null ? null : scholarshipLabel(l10n, scholarshipFor(semester));

    return ListGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.grades_whatIfHint, style: context.text.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.grades_whatIfFinal,
                      style: context.text.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _field,
                      textAlign: TextAlign.end,
                      style: context.text.bodyMedium!.tabular,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: _setFromField,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Slider(
                    value: _final.clamp(0, kMaxScore).toDouble(),
                    min: 0,
                    max: kMaxScore,
                    divisions: kMaxScore.toInt(),
                    label: _final.toStringAsFixed(0),
                    onChanged: _setFromSlider,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListRow(
          title: l10n.grades_total,
          trailing: Text(
            total == null
                ? l10n.grades_scoreEmpty
                : '${formatScore(total)}  ${letterFor(total).letter}',
            style: context.text.bodyMedium!
                .copyWith(color: palette.textPrimary, fontWeight: FontWeight.w600)
                .tabular,
          ),
        ),
        if (status != null)
          ListRow(
            title: l10n.grades_whatIfStatus,
            trailing: StatusLabel(text: status.$1, tone: status.$2),
          ),
        if (semester != null)
          ListRow(
            title: l10n.grades_gpaSemester,
            trailing: Text(
              semesterGpa == null
                  ? l10n.grades_scoreEmpty
                  : formatGpa(semesterGpa),
            ),
          ),
        if (scholarship != null)
          ListRow(
            title: l10n.grades_scholarship,
            trailing: StatusLabel(text: scholarship.$1, tone: scholarship.$2),
          ),
      ],
    );
  }
}
