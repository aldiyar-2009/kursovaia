import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/lesson_dao.dart';
import 'package:studyplan/core/database/subject_dao.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/uuid_util.dart';
import 'package:studyplan/core/widgets/ui/app_sheet.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/features/schedule/domain/schedule_rules.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';

enum _Repeat { every, even, odd, once }

const _newSubjectValue = '__new__';
const _lessonTypes = ['lecture', 'practice', 'lab'];

/// Bottom sheet to add a lesson or edit / delete an existing one.
class LessonEditSheet extends StatefulWidget {
  final AppDatabase db;
  final String userId;

  /// Null to add a new lesson.
  final Lesson? lesson;

  /// Day the user was looking at; preselects weekday and one-off date.
  final DateTime initialDate;

  const LessonEditSheet({
    super.key,
    required this.db,
    required this.userId,
    required this.initialDate,
    this.lesson,
  });

  static Future<void> show(
    BuildContext context, {
    required AppDatabase db,
    required String userId,
    required DateTime initialDate,
    Lesson? lesson,
  }) {
    return showAppSheetCustom<void>(
      context,
      builder: (_) => LessonEditSheet(
        db: db,
        userId: userId,
        initialDate: initialDate,
        lesson: lesson,
      ),
    );
  }

  @override
  State<LessonEditSheet> createState() => _LessonEditSheetState();
}

class _LessonEditSheetState extends State<LessonEditSheet> {
  late final SubjectDao _subjectDao = SubjectDao(widget.db);
  late final LessonDao _lessonDao = LessonDao(widget.db);
  final _newSubjectCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();

  List<Subject>? _subjects;
  String? _subjectId;
  bool _creatingSubject = false;
  late _Repeat _repeat;
  late int _weekday;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late String _type;
  String? _subjectError;
  String? _timeError;
  bool _saving = false;

  bool get _isEdit => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    _date = dayOnly(widget.initialDate);
    if (l == null) {
      _repeat = _Repeat.every;
      _weekday = _date.weekday;
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 9, minute: 50);
      _type = 'lecture';
    } else {
      _subjectId = l.subjectId;
      final specific = l.specificDate;
      if (specific != null && specific.isNotEmpty) {
        _repeat = _Repeat.once;
        _date = DateTime.tryParse(specific) ?? _date;
      } else {
        _repeat = switch (l.isEvenWeek) {
          null => _Repeat.every,
          true => _Repeat.even,
          false => _Repeat.odd,
        };
      }
      _weekday = l.dayOfWeek.clamp(1, 7);
      _start = _parseTime(l.startTime);
      _end = _parseTime(l.endTime);
      _type = _lessonTypes.contains(l.lessonType) ? l.lessonType : 'lecture';
      _roomCtrl.text = l.classroom ?? '';
    }
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final list = await _subjectDao.getAllSubjects(widget.userId);
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _subjects = list;
      if (list.isEmpty) {
        _creatingSubject = true;
      } else if (_subjectId != null && !list.any((s) => s.id == _subjectId)) {
        _subjectId = null;
      }
    });
  }

  @override
  void dispose() {
    _newSubjectCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  static TimeOfDay _parseTime(String s) {
    final m = minutesOf(s).clamp(0, 24 * 60 - 1);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      // Typed 24-hour input: the dial's numbers overlap on small windows.
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        final length = _toMinutes(_end) - _toMinutes(_start);
        _start = picked;
        // Keep the lesson length when moving the start.
        final newEnd = _toMinutes(picked) + (length > 0 ? length : 50);
        if (newEnd < 24 * 60) {
          _end = TimeOfDay(hour: newEnd ~/ 60, minute: newEnd % 60);
        }
      } else {
        _end = picked;
      }
      _timeError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = dayOnly(picked));
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final newTitle = _newSubjectCtrl.text.trim();
    setState(() {
      _subjectError = (_creatingSubject ? newTitle.isEmpty : _subjectId == null)
          ? l10n.schedule_subjectRequired
          : null;
      _timeError = _toMinutes(_end) <= _toMinutes(_start)
          ? l10n.schedule_timeError
          : null;
    });
    if (_subjectError != null || _timeError != null) return;

    setState(() => _saving = true);
    final now = Value(BigInt.from(DateTime.now().millisecondsSinceEpoch));
    final db = widget.db;
    await db.transaction(() async {
      var subjectId = _subjectId;
      if (_creatingSubject) {
        subjectId = UuidUtil.generate();
        await _subjectDao.insertSubject(
          SubjectsCompanion(
            id: Value(subjectId),
            userId: Value(widget.userId),
            title: Value(newTitle),
            updatedAt: now,
            syncStatus: const Value('pending_create'),
          ),
        );
      }
      final once = _repeat == _Repeat.once;
      final room = _roomCtrl.text.trim();
      final fields = LessonsCompanion(
        subjectId: Value(subjectId!),
        dayOfWeek: Value(once ? _date.weekday : _weekday),
        startTime: Value(hhmm(_toMinutes(_start))),
        endTime: Value(hhmm(_toMinutes(_end))),
        classroom: Value(room.isEmpty ? null : room),
        lessonType: Value(_type),
        isEvenWeek: Value(switch (_repeat) {
          _Repeat.even => true,
          _Repeat.odd => false,
          _ => null,
        }),
        specificDate: Value(once ? dateKey(_date) : null),
        updatedAt: now,
      );
      final existing = widget.lesson;
      if (existing == null) {
        await _lessonDao.insertLesson(
          fields.copyWith(
            id: Value(UuidUtil.generate()),
            userId: Value(widget.userId),
            syncStatus: const Value('pending_create'),
          ),
        );
      } else {
        final status = existing.syncStatus == 'pending_create'
            ? 'pending_create'
            : 'pending_update';
        await (db.update(db.lessons)..where((t) => t.id.equals(existing.id)))
            .write(fields.copyWith(syncStatus: Value(status)));
      }
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final p = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.schedule_deleteConfirmTitle),
        content: Text(l10n.schedule_deleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: p.textPrimary),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: p.danger),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _lessonDao.softDeleteLesson(
      widget.lesson!.id,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekdayFmt = DateFormat.E(locale);
    // Any Monday: only used to get localized weekday names.
    final monday = DateTime(2026, 1, 5);

    return AppSheetLayout(
      title: _isEdit ? l10n.schedule_editLesson : l10n.schedule_addLesson,
      primaryAction: FilledButton(
        onPressed: _saving || _subjects == null ? null : _save,
        child: Text(l10n.common_save),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(l10n.schedule_fieldSubject),
          _subjectField(context),
          const SizedBox(height: 20),
          _Label(l10n.schedule_fieldWeek),
          SegmentedToggle<_Repeat>(
            expand: true,
            segments: [
              (_Repeat.every, l10n.schedule_weekEvery),
              (_Repeat.even, l10n.schedule_weekEven),
              (_Repeat.odd, l10n.schedule_weekOdd),
              (_Repeat.once, l10n.schedule_weekOnce),
            ],
            value: _repeat,
            onChanged: (v) => setState(() => _repeat = v),
          ),
          const SizedBox(height: 20),
          if (_repeat == _Repeat.once) ...[
            _Label(l10n.schedule_fieldDate),
            _PickerField(
              value: _capitalize(
                DateFormat('EEEE, d MMMM y', locale).format(_date),
              ),
              onTap: _pickDate,
              icon: Icons.calendar_today_outlined,
            ),
          ] else ...[
            _Label(l10n.schedule_fieldDay),
            SegmentedToggle<int>(
              expand: true,
              height: 40,
              segments: [
                for (var i = 0; i < 7; i++)
                  (
                    i + 1,
                    _capitalize(
                      weekdayFmt.format(
                        DateTime(monday.year, monday.month, monday.day + i),
                      ),
                    ),
                  ),
              ],
              value: _weekday,
              onChanged: (v) => setState(() => _weekday = v),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Label(l10n.schedule_fieldStart),
                    _PickerField(
                      value: hhmm(_toMinutes(_start)),
                      tabular: true,
                      onTap: () => _pickTime(start: true),
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Label(l10n.schedule_fieldEnd),
                    _PickerField(
                      value: hhmm(_toMinutes(_end)),
                      tabular: true,
                      error: _timeError != null,
                      onTap: () => _pickTime(start: false),
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_timeError != null) _ErrorText(_timeError!),
          const SizedBox(height: 20),
          _Label(l10n.schedule_fieldType),
          SegmentedToggle<String>(
            expand: true,
            segments: [
              ('lecture', l10n.schedule_typeLecture),
              ('practice', l10n.schedule_typePractice),
              ('lab', l10n.schedule_typeLabShort),
            ],
            value: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _roomCtrl,
            label: l10n.schedule_fieldRoom,
            hint: l10n.schedule_roomHint,
            textInputAction: TextInputAction.done,
          ),
          if (_isEdit) ...[
            const SizedBox(height: 16),
            // Destructive action stays in the body; the pinned
            // button is only for saving.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: p.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(l10n.schedule_deleteLesson),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _subjectField(BuildContext context) {
    final l10n = context.l10n;
    final subjects = _subjects;
    if (subjects == null) {
      return const SizedBox(height: 48);
    }
    final newField = AppTextField(
      controller: _newSubjectCtrl,
      hint: l10n.schedule_subjectNewHint,
      autofocus: subjects.isEmpty && !_isEdit,
      errorText: _creatingSubject ? _subjectError : null,
      textInputAction: TextInputAction.next,
      onChanged: (_) {
        if (_subjectError != null) setState(() => _subjectError = null);
      },
    );
    if (subjects.isEmpty) return newField;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _creatingSubject ? _newSubjectValue : _subjectId,
          isExpanded: true,
          hint: Text(l10n.schedule_subjectPick),
          style: context.text.bodyMedium,
          dropdownColor: context.palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          decoration: InputDecoration(
            errorText: _creatingSubject ? null : _subjectError,
          ),
          items: [
            for (final s in subjects)
              DropdownMenuItem(
                value: s.id,
                child: Text(s.title, overflow: TextOverflow.ellipsis),
              ),
            DropdownMenuItem(
              value: _newSubjectValue,
              child: Text(
                l10n.schedule_subjectNew,
                style: context.text.bodyMedium!.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() {
            _subjectError = null;
            if (v == _newSubjectValue) {
              _creatingSubject = true;
            } else {
              _creatingSubject = false;
              _subjectId = v;
            }
          }),
        ),
        if (_creatingSubject) ...[const SizedBox(height: 8), newField],
      ],
    );
  }
}

String _capitalize(String s) {
  final t = s.replaceAll('.', '');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: context.text.labelMedium!.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;

  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: context.text.bodySmall!.copyWith(color: context.palette.danger),
      ),
    );
  }
}

/// Tappable field that looks like a text input and opens a picker.
class _PickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  final IconData icon;
  final bool tabular;
  final bool error;

  const _PickerField({
    required this.value,
    required this.onTap,
    required this.icon,
    this.tabular = false,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = context.text.bodyMedium!;
    const radius = BorderRadius.all(Radius.circular(AppRadius.md));
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: error ? p.danger : p.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tabular ? style.tabular : style,
                  ),
                ),
                Icon(icon, size: 18, color: p.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
