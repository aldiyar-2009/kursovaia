import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/features/group/data/group_repository.dart';
import 'package:studyplan/features/group/presentation/widgets/group_forms.dart';
import 'package:studyplan/features/materials/presentation/screens/materials_screen.dart';

/// Shares [text] through the system share sheet. Throws when sharing is not
/// possible; the caller then copies the text to the clipboard instead.
typedef ShareTextFn = Future<void> Function(String text, String subject);

Future<void> _systemShare(String text, String subject) async {
  // `ShareResultStatus.unavailable` only means the outcome is unknown (the
  // Windows share UI reports it after opening), so it is not a failure.
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

/// Group: invite code, members, shared materials; create / join / leave.
///
/// The group is refreshed from `GET /groups/me` on open and after every
/// change; the result is saved to SharedPreferences (`group_data`) and
/// reported through [onGroupChanged].
class GroupScreen extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final String userId;

  /// Group known to the caller (from `group_data`), shown until the refresh
  /// completes.
  final Map<String, dynamic>? group;

  /// Called with the new group (null after leaving) whenever it changes.
  final ValueChanged<Map<String, dynamic>?>? onGroupChanged;

  /// Share implementation; the system share sheet by default (none on the
  /// web, where the invite text is copied to the clipboard instead).
  final ShareTextFn? onShare;

  const GroupScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.userId,
    this.group,
    this.onGroupChanged,
    this.onShare,
  });

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late final GroupRepository _repo = GroupRepository(widget.apiClient);
  late GroupSnapshot _snapshot = GroupSnapshot(group: widget.group);
  bool _loading = true;
  bool _offline = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cached = await _repo.loadCached();
    if (!mounted) return;
    final known = widget.group?['id'];
    if (cached.group != null &&
        (known == null || cached.group!['id'] == known)) {
      setState(() => _snapshot = cached);
    }
    await _refresh();
    if (!mounted || _snapshot.group != null) return;
    final pending = await GroupRepository.takePendingInviteCode();
    if (pending != null && mounted) _join(initialCode: pending);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fresh = await _repo.refresh();
      if (!mounted) return;
      final changed =
          fresh.group?['id'] != _snapshot.group?['id'] ||
          fresh.title != _snapshot.title;
      setState(() {
        _snapshot = fresh;
        _offline = false;
        _loading = false;
      });
      if (changed) widget.onGroupChanged?.call(fresh.group);
    } on GroupException {
      if (!mounted) return;
      setState(() {
        _offline = true;
        _loading = false;
      });
    }
  }

  void _apply(GroupSnapshot snapshot) {
    setState(() {
      _snapshot = snapshot;
      _offline = false;
    });
    widget.onGroupChanged?.call(snapshot.group);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final result = await showCreateGroupSheet(context, _repo);
    if (result == null || !mounted) return;
    _apply(result);
    _snack(l10n.group_createDone);
  }

  Future<void> _join({String? initialCode}) async {
    final l10n = context.l10n;
    final result = await showJoinGroupSheet(
      context,
      _repo,
      initialCode: initialCode,
    );
    if (result == null || !mounted) return;
    _apply(result);
    _snack(l10n.group_joinDone(result.title ?? ''));
  }

  Future<void> _copyCode(String code) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _snack(l10n.group_copied);
  }

  Future<void> _invite(String title, String code) async {
    final l10n = context.l10n;
    final text = l10n.group_inviteMessage(
      title,
      code,
      _repo.inviteLinkFor(code),
    );
    // On the web the share sheet is missing or silently does nothing, so the
    // invite goes to the clipboard; elsewhere the clipboard is the fallback
    // when sharing throws or is unsupported.
    final share = widget.onShare ?? (kIsWeb ? null : _systemShare);
    if (share != null) {
      try {
        await share(text, l10n.group_title);
        return;
      } catch (_) {
        // Fall through to the clipboard.
      }
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _snack(l10n.group_inviteCopied);
  }

  Future<void> _leave() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.group_leaveConfirmTitle),
        content: Text(l10n.group_leaveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.danger,
            ),
            child: Text(l10n.group_leaveConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _repo.leave();
      if (!mounted) return;
      _apply(result);
      _snack(l10n.group_leaveDone);
    } on GroupException catch (e) {
      if (mounted) _snack(groupFailureText(l10n, e.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMaterials() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MaterialsScreen(
          db: widget.db,
          apiClient: widget.apiClient,
          userId: widget.userId,
          groupId: _snapshot.group?['id'] as String?,
          onGroupChanged: (group) => _refresh(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final group = _snapshot.group;
    final Widget body;
    if (group == null) {
      body = _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                if (_offline)
                  ContentColumn(child: _OfflineNotice(onRetry: _refresh)),
                Expanded(
                  child: GroupJoinEmptyState(
                    onJoin: () => _join(),
                    onCreate: _create,
                  ),
                ),
              ],
            );
    } else {
      body = _GroupDetails(
        snapshot: _snapshot,
        userId: widget.userId,
        offline: _offline,
        busy: _busy,
        onRetry: _refresh,
        onCopy: _copyCode,
        onInvite: _invite,
        onOpenMaterials: _openMaterials,
        onLeave: _leave,
      );
    }
    return Scaffold(
      appBar: ContentAppBar(
        title: Text(l10n.group_title),
        bottom: _loading && group != null
            ? const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: LinearProgressIndicator(minHeight: 1),
              )
            : null,
      ),
      body: body,
    );
  }
}

class _GroupDetails extends StatelessWidget {
  final GroupSnapshot snapshot;
  final String userId;
  final bool offline;
  final bool busy;
  final VoidCallback onRetry;
  final ValueChanged<String> onCopy;
  final void Function(String title, String code) onInvite;
  final VoidCallback onOpenMaterials;
  final VoidCallback onLeave;

  const _GroupDetails({
    required this.snapshot,
    required this.userId,
    required this.offline,
    required this.busy,
    required this.onRetry,
    required this.onCopy,
    required this.onInvite,
    required this.onOpenMaterials,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final title = snapshot.title ?? '';
    final code = snapshot.inviteCode ?? '';
    final members = snapshot.members;

    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: contentPadding(constraints.maxWidth, top: 4, bottom: 32),
        children: [
          if (offline) ...[
            _OfflineNotice(onRetry: onRetry),
            const SizedBox(height: 8),
          ],
          Text(title, style: context.text.titleLarge),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.group_membersCount(members.length),
              style: context.text.bodySmall,
            ),
          ],
          SectionHeader(l10n.group_inviteSection),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  code,
                  style: context.text.titleLarge!
                      .copyWith(letterSpacing: 3)
                      .tabular,
                ),
                const SizedBox(height: 4),
                Text(l10n.group_inviteHint, style: context.text.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: code.isEmpty ? null : () => onCopy(code),
                        child: Text(
                          l10n.group_copy,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: code.isEmpty
                            ? null
                            : () => onInvite(title, code),
                        child: Text(
                          l10n.group_invite,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListGroup(
            children: [
              ListRow(
                title: l10n.group_materials,
                trailing: const ListRowChevron(),
                onTap: onOpenMaterials,
              ),
            ],
          ),
          SectionHeader(l10n.group_membersSection),
          if (members.isEmpty)
            ListGroup(
              children: [
                ListRow(
                  title: l10n.group_membersUnavailable,
                  titleColor: palette.textSecondary,
                  trailing: TextButton(
                    onPressed: onRetry,
                    child: Text(l10n.common_retry),
                  ),
                ),
              ],
            )
          else
            ListGroup(
              children: [
                for (final m in members)
                  ListRow(
                    title: m.name,
                    trailing: m.id == userId
                        ? Text(l10n.group_memberYou)
                        : null,
                  ),
              ],
            ),
          const SizedBox(height: 24),
          ListGroup(
            children: [
              ListRow(
                title: l10n.group_leave,
                titleColor: palette.danger,
                onTap: busy ? null : onLeave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Quiet one-line notice that the data could not be refreshed.
class _OfflineNotice extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineNotice({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(l10n.group_offlineNotice, style: context.text.bodySmall),
        ),
        TextButton(onPressed: onRetry, child: Text(l10n.common_retry)),
      ],
    );
  }
}
