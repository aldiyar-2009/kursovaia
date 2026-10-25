import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/app_sheet.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/features/group/data/group_repository.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

String groupFailureText(AppLocalizations l10n, GroupFailure failure) =>
    switch (failure) {
      GroupFailure.codeNotFound => l10n.group_errorCodeNotFound,
      GroupFailure.alreadyMember => l10n.group_errorAlreadyMember,
      GroupFailure.offline => l10n.group_errorOffline,
      GroupFailure.generic => l10n.group_errorGeneric,
    };

/// "Вы не в группе" with join (primary) and create (secondary) actions.
class GroupJoinEmptyState extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  const GroupJoinEmptyState({
    super.key,
    this.title,
    this.message,
    required this.onJoin,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      title: title ?? l10n.group_emptyTitle,
      message: message ?? l10n.group_emptyMessage,
      actionLabel: l10n.group_join,
      onAction: onJoin,
      secondaryLabel: l10n.group_create,
      onSecondary: onCreate,
    );
  }
}

/// Bottom sheet that creates a group. Returns the refreshed snapshot.
Future<GroupSnapshot?> showCreateGroupSheet(
  BuildContext context,
  GroupRepository repository,
) {
  final l10n = context.l10n;
  return _showFormSheet(
    context,
    title: l10n.group_createTitle,
    fieldLabel: l10n.group_createNameLabel,
    fieldHint: l10n.group_createNameHint,
    submitLabel: l10n.group_createSubmit,
    maxLength: 64,
    onSubmit: repository.create,
  );
}

/// Bottom sheet that joins a group by invite code.
Future<GroupSnapshot?> showJoinGroupSheet(
  BuildContext context,
  GroupRepository repository, {
  String? initialCode,
}) {
  final l10n = context.l10n;
  return _showFormSheet(
    context,
    title: l10n.group_joinTitle,
    fieldLabel: l10n.group_joinCodeLabel,
    fieldHint: l10n.group_joinCodeHint,
    submitLabel: l10n.group_joinSubmit,
    initialValue: initialCode,
    maxLength: 16,
    formatters: [
      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
      _UpperCaseFormatter(),
    ],
    onSubmit: repository.join,
  );
}

Future<GroupSnapshot?> _showFormSheet(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String fieldHint,
  required String submitLabel,
  required Future<GroupSnapshot> Function(String value) onSubmit,
  required int maxLength,
  String? initialValue,
  List<TextInputFormatter>? formatters,
}) {
  return showAppSheetCustom<GroupSnapshot>(
    context,
    builder: (_) => _FormSheet(
      title: title,
      fieldLabel: fieldLabel,
      fieldHint: fieldHint,
      submitLabel: submitLabel,
      initialValue: initialValue,
      maxLength: maxLength,
      formatters: formatters,
      onSubmit: onSubmit,
    ),
  );
}

class _FormSheet extends StatefulWidget {
  final String title;
  final String fieldLabel;
  final String fieldHint;
  final String submitLabel;
  final String? initialValue;
  final int maxLength;
  final List<TextInputFormatter>? formatters;
  final Future<GroupSnapshot> Function(String value) onSubmit;

  const _FormSheet({
    required this.title,
    required this.fieldLabel,
    required this.fieldHint,
    required this.submitLabel,
    required this.initialValue,
    required this.maxLength,
    required this.formatters,
    required this.onSubmit,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = l10n.group_fieldRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await widget.onSubmit(value);
      if (mounted) Navigator.of(context).pop(snapshot);
    } on GroupException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = groupFailureText(l10n, e.failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetLayout(
      title: widget.title,
      body: AppTextField(
        controller: _controller,
        label: widget.fieldLabel,
        hint: widget.fieldHint,
        errorText: _error,
        autofocus: true,
        enabled: !_busy,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          LengthLimitingTextInputFormatter(widget.maxLength),
          ...?widget.formatters,
        ],
        onSubmitted: (_) => _submit(),
      ),
      primaryAction: FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.submitLabel),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
