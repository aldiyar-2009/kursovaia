import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/features/schedule/data/schedule_exchange.dart';

/// Export the own timetable as JSON, or import one from a groupmate.
class ScheduleExchangeScreen extends StatefulWidget {
  final AppDatabase db;
  final String userId;
  final String? groupName;

  const ScheduleExchangeScreen({
    super.key,
    required this.db,
    required this.userId,
    this.groupName,
  });

  @override
  State<ScheduleExchangeScreen> createState() => _ScheduleExchangeScreenState();
}

class _ScheduleExchangeScreenState extends State<ScheduleExchangeScreen> {
  bool _import = false;
  String? _exported;
  bool _hasLessons = false;
  final _input = TextEditingController();
  DateTime _validFrom = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _export();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final json = await exportScheduleJson(
      widget.db,
      widget.userId,
      groupName: widget.groupName,
    );
    final lessons =
        await (widget.db.select(widget.db.lessons)..where(
              (t) => t.userId.equals(widget.userId) & t.isDeleted.equals(false),
            ))
            .get();
    if (!mounted) return;
    setState(() {
      _exported = json;
      _hasLessons = lessons.isNotEmpty;
    });
  }

  Future<void> _copy() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _exported ?? ''));
    messenger.showSnackBar(SnackBar(content: Text(l10n.exchange_copied)));
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: _exported ?? '', subject: context.l10n.exchange_title),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _validFrom = picked);
  }

  Future<void> _doImport() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await importScheduleJson(
        widget.db,
        widget.userId,
        _input.text,
        validFrom: DateFormat('yyyy-MM-dd').format(_validFrom),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exchange_imported(count))),
      );
      _input.clear();
      await _export();
    } on FormatException {
      if (mounted) setState(() => _error = l10n.exchange_invalid);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: ContentAppBar(title: Text(l10n.exchange_title)),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: contentPadding(constraints.maxWidth, top: 0, bottom: 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SegmentedToggle<bool>(
                  expand: true,
                  segments: [
                    (false, l10n.exchange_export),
                    (true, l10n.exchange_import),
                  ],
                  value: _import,
                  onChanged: (v) => setState(() => _import = v),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...(_import ? _importBody(context) : _exportBody(context)),
          ],
        ),
      ),
    );
  }

  List<Widget> _exportBody(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final json = _exported;
    if (json == null) return const [Center(child: CircularProgressIndicator())];
    if (!_hasLessons) {
      return [Text(l10n.exchange_empty, style: context.text.bodyMedium)];
    }
    return [
      Text(l10n.exchange_exportHint, style: context.text.bodySmall),
      const SizedBox(height: 12),
      Container(
        constraints: const BoxConstraints(maxHeight: 320),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: p.border),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            json,
            style: context.text.bodySmall!.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(l10n.exchange_copy),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: Text(l10n.exchange_share),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _importBody(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return [
      Text(l10n.exchange_importHint, style: context.text.bodySmall),
      const SizedBox(height: 12),
      AppTextField(
        controller: _input,
        label: l10n.exchange_jsonLabel,
        maxLines: 10,
        errorText: _error,
        keyboardType: TextInputType.multiline,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text(
            l10n.exchange_validFrom(
              DateFormat.yMMMd(locale).format(_validFrom),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _busy ? null : _doImport,
        child: Text(l10n.exchange_importAction),
      ),
    ];
  }
}
