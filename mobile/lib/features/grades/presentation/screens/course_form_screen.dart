import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/features/grades/domain/grade_calculator.dart';
import 'package:studyplan/features/grades/domain/grading_rules.dart';
import 'package:studyplan/features/grades/presentation/grades_presentation.dart';
import 'package:uuid/uuid.dart';

/// Credits range accepted by the server (`lms_courses.credits`).
const int kMinCredits = 1;
const int kMaxCredits = 30;

/// Adds a manual course, or edits the scores of an existing manual course.
class CourseFormScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  /// The manual course to edit; null to create a new one.
  final LmsCourse? course;

  const CourseFormScreen({
    super.key,
    required this.db,
    required this.userId,
    this.course,
  });

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _credits;
  late final TextEditingController _midterm;
  late final TextEditingController _endterm;
  late final TextEditingController _final;
  late final TextEditingController _total;
  late bool _past;
  bool _saving = false;

  bool get _isEdit => widget.course != null;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    String fmt(double? v) => v == null ? '' : formatScore(v);
    _title = TextEditingController(text: c?.title ?? '');
    _credits = TextEditingController(text: '${c?.credits ?? kDefaultCredits}');
    _midterm = TextEditingController(text: fmt(c?.registerMidterm));
    _endterm = TextEditingController(text: fmt(c?.registerEndterm));
    _final = TextEditingController(text: fmt(c?.finalExam));
    final complete = c != null &&
        c.registerMidterm != null &&
        c.registerEndterm != null &&
        c.finalExam != null;
    // A stored total of a complete course is derived; only a standalone
    // total is something the user typed.
    _total = TextEditingController(text: complete ? '' : fmt(c?.total));
    _past = c?.classification == 'past';
  }

  @override
  void dispose() {
    for (final c in [_title, _credits, _midterm, _endterm, _final, _total]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateScore(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final v = parseScore(raw);
    if (v == null || v < 0 || v > kMaxScore) {
      return context.l10n.grades_formScoreInvalid;
    }
    return null;
  }

  String? _validateCredits(String? raw) {
    final v = int.tryParse(raw?.trim() ?? '');
    if (v == null || v < kMinCredits || v > kMaxCredits) {
      return context.l10n.grades_formCreditsInvalid;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final midterm = parseScore(_midterm.text);
    final endterm = parseScore(_endterm.text);
    final finalExam = parseScore(_final.text);
    final credits = int.parse(_credits.text.trim());
    final complete = midterm != null && endterm != null && finalExam != null;
    final total = complete
        ? courseTotal(CourseScores(
            midterm: midterm,
            endterm: endterm,
            finalExam: finalExam,
          ))
        : parseScore(_total.text);

    final base = widget.course?.toCompanion(false) ??
        LmsCoursesCompanion(
          id: Value(const Uuid().v4()),
          userId: Value(widget.userId),
          source: const Value('manual'),
        );
    await widget.db.lmsDao.upsertManualCourse(base.copyWith(
      title: Value(_title.text.trim()),
      credits: Value(credits),
      classification: Value(_past ? 'past' : 'inprogress'),
      registerMidterm: Value(midterm),
      registerEndterm: Value(endterm),
      finalExam: Value(finalExam),
      total: Value(total),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scoreFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      LengthLimitingTextInputFormatter(5),
    ];
    const scoreKeyboard = TextInputType.numberWithOptions(decimal: true);

    Widget scoreField(TextEditingController c, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppTextField(
            controller: c,
            label: label,
            hint: l10n.grades_scoreEmpty,
            keyboardType: scoreKeyboard,
            inputFormatters: scoreFormatters,
            textInputAction: TextInputAction.next,
            validator: _validateScore,
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.grades_formEditTitle : l10n.grades_formAddTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  AppTextField(
                    controller: _title,
                    label: l10n.grades_formName,
                    hint: l10n.grades_formNameHint,
                    autofocus: !_isEdit,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.grades_formNameRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: AppTextField(
                          controller: _credits,
                          label: l10n.grades_creditsLabel,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          validator: _validateCredits,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.grades_formSemester,
                              style: context.text.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<bool>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: false,
                                    label: Text(l10n.grades_formSemesterCurrent),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text(l10n.grades_formSemesterPast),
                                  ),
                                ],
                                selected: {_past},
                                onSelectionChanged: (s) =>
                                    setState(() => _past = s.first),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.grades_formScoresSection,
                    style: context.text.titleSmall,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Text(
                      l10n.grades_formScoresHelp,
                      style: context.text.bodySmall,
                    ),
                  ),
                  scoreField(_midterm, l10n.grades_midterm),
                  scoreField(_endterm, l10n.grades_endterm),
                  scoreField(_final, l10n.grades_finalExam),
                  scoreField(_total, l10n.grades_total),
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: Text(
                      l10n.grades_formTotalHelp,
                      style: context.text.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l10n.common_save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
