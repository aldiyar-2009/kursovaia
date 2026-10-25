import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/subject_dao.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/features/materials/data/materials_repository.dart';

/// Asks for a title and subject for [file] and uploads it.
/// Returns true when the upload succeeded.
Future<bool?> showUploadMaterialSheet(
  BuildContext context, {
  required AppDatabase db,
  required String userId,
  required MaterialsRepository repository,
  required PlatformFile file,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _UploadSheet(
      db: db,
      userId: userId,
      repository: repository,
      file: file,
    ),
  );
}

class _UploadSheet extends StatefulWidget {
  final AppDatabase db;
  final String userId;
  final MaterialsRepository repository;
  final PlatformFile file;

  const _UploadSheet({
    required this.db,
    required this.userId,
    required this.repository,
    required this.file,
  });

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  late final TextEditingController _title = TextEditingController(
    text: _stripExtension(widget.file.name),
  );
  List<String> _subjects = const [];
  String? _subject;
  bool _busy = false;
  String? _titleError;
  String? _error;

  static String _stripExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  @override
  void initState() {
    super.initState();
    SubjectDao(widget.db).getAllSubjects(widget.userId).then((list) {
      if (!mounted) return;
      final titles = {for (final s in list) s.title.trim()}
          .where((t) => t.isNotEmpty)
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() => _subjects = titles);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = l10n.group_fieldRequired);
      return;
    }
    setState(() {
      _busy = true;
      _titleError = null;
      _error = null;
    });
    try {
      final bytes = await widget.file.readAsBytes();
      await widget.repository.upload(
        bytes: bytes,
        fileName: widget.file.name,
        title: title,
        subjectTitle: _subject,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on MaterialsException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.failure) {
          MaterialsFailure.offline => l10n.group_errorOffline,
          MaterialsFailure.tooLarge => l10n.group_materialsFileTooLarge,
          _ => l10n.group_materialsUploadFailed,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.group_materialsUploadFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.group_materialsUploadTitle, style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text(
            widget.file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _title,
            label: l10n.group_materialsUploadNameLabel,
            errorText: _titleError,
            enabled: !_busy,
            inputFormatters: [LengthLimitingTextInputFormatter(160)],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.group_materialsUploadSubjectLabel,
            style: context.text.labelMedium!
                .copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: _subject,
            isExpanded: true,
            dropdownColor: palette.surface,
            borderRadius: BorderRadius.circular(8),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.group_materialsNoSubject),
              ),
              for (final s in _subjects)
                DropdownMenuItem<String?>(
                  value: s,
                  child: Text(s, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _subject = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: context.text.bodySmall!.copyWith(color: palette.danger),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.group_materialsUploadSubmit),
          ),
        ],
      ),
    );
  }
}
