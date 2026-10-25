import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/services/ics_export_service.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/file_download_helper.dart';
import 'package:studyplan/core/widgets/server_config_dialog.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/features/profile/data/deadline_reminders.dart';
import 'package:studyplan/features/profile/presentation/widgets/choice_screen.dart';

/// Language names are always shown in their own language, so they are not
/// translated and do not live in the ARB files.
const _kLanguageNames = <String, String>{
  'ru': 'Русский',
  'en': 'English',
  'kk': 'Қазақша',
};

/// Profile and app settings, grouped like system settings.
class ProfileScreen extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? group;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>>? onUserUpdated;

  /// Opens the LMS import. The «Подключить LMS» row is hidden when this is
  /// null or on the web.
  final VoidCallback? onImportLms;

  const ProfileScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
    required this.user,
    this.group,
    required this.onLogout,
    this.onUserUpdated,
    this.onImportLms,
  });

  /// SharedPreferences key with the LMS profile JSON written by the importer.
  static const lmsProfileKey = 'lms.profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _user;
  late final DeadlineReminders _reminders;
  String? _lmsName;
  String? _lmsEmail;
  bool _remindersEnabled = false;
  bool _remindersBusy = false;
  bool _exporting = false;

  String get _userId => _user['id'] as String? ?? '';
  String? get _groupId => widget.group?['id'] as String?;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _reminders = DeadlineReminders(widget.db);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String? lmsName;
    String? lmsEmail;
    final raw = prefs.getString(ProfileScreen.lmsProfileKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        lmsName = (json['fullName'] as String?)?.trim();
        lmsEmail = (json['email'] as String?)?.trim();
      } catch (_) {
        // Corrupt value: treat as not connected.
      }
    }
    if (!mounted) return;
    setState(() {
      _lmsName = (lmsName?.isEmpty ?? true) ? null : lmsName;
      _lmsEmail = (lmsEmail?.isEmpty ?? true) ? null : lmsEmail;
      _remindersEnabled = prefs.getBool(DeadlineReminders.prefsKey) ?? false;
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------------------------------------------------------- name

  Future<void> _editName() async {
    final l10n = context.l10n;
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: _user['name'] as String? ?? ''),
    );
    if (newName == null || newName == _user['name']) return;

    final prefs = await SharedPreferences.getInstance();
    try {
      final res =
          await widget.apiClient.dio.patch('/auth/me', data: {'name': newName});
      final updated = (res.data as Map<String, dynamic>)['user']
          as Map<String, dynamic>;
      await prefs.setString('user_data', jsonEncode(updated));
      if (!mounted) return;
      setState(() => _user = updated);
      widget.onUserUpdated?.call(updated);
      _snack(l10n.profile_nameSaved);
    } catch (_) {
      final updated = {..._user, 'name': newName};
      await prefs.setString('user_data', jsonEncode(updated));
      if (!mounted) return;
      setState(() => _user = updated);
      widget.onUserUpdated?.call(updated);
      _snack(l10n.profile_nameSavedLocally);
    }
  }

  // ------------------------------------------------------------ settings

  String _languageLabel(Locale? locale) => locale == null
      ? context.l10n.profile_languageSystem
      : _kLanguageNames[locale.languageCode] ?? locale.languageCode;

  void _openTheme() {
    final settings = widget.settings;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => ChoiceScreen<ThemeMode>(
        title: ctx.l10n.profile_theme,
        listenable: settings,
        selected: () => settings.themeMode,
        onSelected: settings.setThemeMode,
        options: [
          for (final mode in ThemeMode.values)
            ChoiceOption(value: mode, title: _themeLabelIn(ctx, mode)),
        ],
      ),
    ));
  }

  String _themeLabelIn(BuildContext ctx, ThemeMode mode) => switch (mode) {
        ThemeMode.system => ctx.l10n.profile_themeSystem,
        ThemeMode.light => ctx.l10n.profile_themeLight,
        ThemeMode.dark => ctx.l10n.profile_themeDark,
      };

  void _openLanguage() {
    final settings = widget.settings;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => ChoiceScreen<String>(
        title: ctx.l10n.profile_language,
        listenable: settings,
        selected: () => settings.locale?.languageCode ?? '',
        onSelected: (code) =>
            settings.setLocale(code.isEmpty ? null : Locale(code)),
        options: [
          ChoiceOption(
            value: '',
            title: ctx.l10n.profile_languageSystem,
            subtitle: ctx.l10n.profile_languageSystemHint,
          ),
          for (final locale in kSupportedLocales)
            ChoiceOption(
              value: locale.languageCode,
              title: _kLanguageNames[locale.languageCode]!,
            ),
        ],
      ),
    ));
  }

  Future<void> _toggleReminders(bool enabled) async {
    final l10n = context.l10n;
    setState(() {
      _remindersEnabled = enabled;
      _remindersBusy = true;
    });
    try {
      final count =
          await _reminders.setEnabled(enabled, _userId, groupId: _groupId);
      if (!mounted) return;
      _snack(enabled ? l10n.profile_remindersOn(count) : l10n.profile_remindersOff);
    } finally {
      if (mounted) setState(() => _remindersBusy = false);
    }
  }

  Future<void> _exportIcs() async {
    final l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      final ics = await IcsExportService.generateScheduleIcs(
        widget.db,
        _userId,
        untitledLesson: l10n.schedule_lessonUntitled,
      );
      if (!ics.contains('BEGIN:VEVENT')) {
        _snack(l10n.profile_exportIcsEmpty);
        return;
      }
      const fileName = 'studyplan-schedule.ics';
      final bytes = Uint8List.fromList(utf8.encode(ics));
      if (kIsWeb) {
        downloadBytesWeb(bytes, fileName);
        _snack(l10n.profile_exportIcsDone);
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'text/calendar', name: fileName),
          ],
          fileNameOverrides: const [fileName],
        ));
      }
    } catch (_) {
      if (mounted) _snack(l10n.profile_exportIcsFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmLogout() async {
    final l10n = context.l10n;
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profile_logoutTitle),
        content: Text(l10n.profile_logoutMessage),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profile_logout),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLogout();
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final name = (_user['name'] as String?)?.trim();
    final email = (_user['email'] as String?)?.trim();
    final hasLms = _lmsName != null || _lmsEmail != null;
    final canImportLms = widget.onImportLms != null && !kIsWeb;

    Widget progress() => const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

    final sections = <Widget>[
      const SizedBox(height: 8),
      ListGroup(children: [
        ListRow(
          title: (name == null || name.isEmpty) ? l10n.profile_noName : name,
          subtitle: (email == null || email.isEmpty) ? null : email,
          trailing: Tooltip(
            message: l10n.profile_editName,
            child: const Icon(Icons.edit_outlined),
          ),
          onTap: _editName,
        ),
      ]),
      if (hasLms || canImportLms) ...[
        SectionHeader(l10n.profile_sectionLms),
        ListGroup(children: [
          if (hasLms) ...[
            if (_lmsName != null)
              _ValueRow(label: l10n.profile_lmsFullName, value: _lmsName!),
            if (_lmsEmail != null)
              _ValueRow(label: l10n.profile_lmsEmail, value: _lmsEmail!),
          ] else
            ListRow(
              title: l10n.profile_lmsConnect,
              subtitle: l10n.profile_lmsConnectHint,
              trailing: const ListRowChevron(),
              onTap: widget.onImportLms,
            ),
        ]),
      ],
      SectionHeader(l10n.profile_sectionAppearance),
      ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => ListGroup(children: [
          ListRow(
            title: l10n.profile_theme,
            trailing: _TrailingValue(
              _themeLabelIn(context, widget.settings.themeMode),
            ),
            onTap: _openTheme,
          ),
          ListRow(
            title: l10n.profile_language,
            trailing: _TrailingValue(_languageLabel(widget.settings.locale)),
            onTap: _openLanguage,
          ),
        ]),
      ),
      if (!kIsWeb) ...[
        SectionHeader(l10n.profile_sectionNotifications),
        ListGroup(children: [
          MergeSemantics(
            child: ListRow(
              title: l10n.profile_deadlineReminders,
              subtitle: l10n.profile_deadlineRemindersHint,
              trailing: Switch(
                value: _remindersEnabled,
                onChanged: _remindersBusy ? null : _toggleReminders,
              ),
              onTap: _remindersBusy
                  ? null
                  : () => _toggleReminders(!_remindersEnabled),
            ),
          ),
        ]),
      ],
      SectionHeader(l10n.profile_sectionData),
      ListGroup(children: [
        ListRow(
          title: l10n.profile_exportIcs,
          subtitle: l10n.profile_exportIcsHint,
          trailing: _exporting ? progress() : null,
          onTap: _exporting ? null : _exportIcs,
        ),
        ListRow(
          title: l10n.profile_server,
          subtitle: widget.apiClient.dio.options.baseUrl,
          trailing: const ListRowChevron(),
          onTap: () => ServerConfigDialog.show(
            context,
            widget.apiClient,
            onSaved: () {
              if (mounted) setState(() {});
            },
          ),
        ),
      ]),
      const SizedBox(height: 32),
      ListGroup(children: [
        ListRow(
          title: l10n.profile_logout,
          titleColor: palette.danger,
          onTap: _confirmLogout,
        ),
      ]),
    ];

    return Scaffold(
      appBar: ContentAppBar(title: Text(l10n.profile_title)),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: contentPadding(constraints.maxWidth, bottom: 32),
          children: sections,
        ),
      ),
    );
  }
}

/// Current value next to a chevron, e.g. «Тёмная ›».
class _TrailingValue extends StatelessWidget {
  final String value;

  const _TrailingValue(this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 4),
        const ListRowChevron(),
      ],
    );
  }
}

/// Read-only label / value row.
class _ValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: label,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          value,
          maxLines: 2,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initial;

  const _EditNameDialog({required this.initial});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = context.l10n.profile_nameRequired);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.profile_editName),
      content: SizedBox(
        width: 360,
        child: AppTextField(
          controller: _controller,
          label: l10n.profile_nameLabel,
          autofocus: true,
          errorText: _error,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.palette.textSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.common_save)),
      ],
    );
  }
}
