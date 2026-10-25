import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/section_header.dart';
import 'package:studyplan/features/group/data/group_repository.dart';
import 'package:studyplan/features/group/presentation/widgets/group_forms.dart';
import 'package:studyplan/features/materials/data/group_material.dart';
import 'package:studyplan/features/materials/data/materials_repository.dart';
import 'package:studyplan/features/materials/presentation/widgets/upload_material_sheet.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app; returns false when it could not.
typedef OpenUrlFn = Future<bool> Function(Uri url);

Future<bool> _openExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

const double _maxContentWidth = 720;

/// Materials: files shared with the group (server) and course materials
/// imported from LMS (drift).
class MaterialsScreen extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final String userId;

  /// The user's group id; null shows the join / create empty state.
  final String? groupId;

  /// Called after the user joins or creates a group from this screen.
  final ValueChanged<Map<String, dynamic>?>? onGroupChanged;

  /// 0 — group, 1 — LMS.
  final int initialTab;

  /// URL opener for LMS materials; the external browser by default.
  final OpenUrlFn? openUrl;

  const MaterialsScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.userId,
    this.groupId,
    this.onGroupChanged,
    this.initialTab = 0,
    this.openUrl,
  });

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  late String? _groupId = widget.groupId;
  final _groupTabKey = GlobalKey<_GroupMaterialsTabState>();

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onGroupChanged(Map<String, dynamic>? group) {
    setState(() => _groupId = group?['id'] as String?);
    widget.onGroupChanged?.call(group);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canUpload = _tabs.index == 0 && _groupId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.group_materialsTitle),
        actions: [
          if (canUpload)
            IconButton(
              tooltip: l10n.group_materialsUpload,
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: () => _groupTabKey.currentState?.upload(),
            ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.group_materialsTabGroup),
            Tab(text: l10n.group_materialsTabLms),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _GroupMaterialsTab(
            key: _groupTabKey,
            db: widget.db,
            apiClient: widget.apiClient,
            userId: widget.userId,
            groupId: _groupId,
            onGroupChanged: _onGroupChanged,
          ),
          _LmsMaterialsTab(
            db: widget.db,
            userId: widget.userId,
            openUrl: widget.openUrl ?? _openExternal,
          ),
        ],
      ),
    );
  }
}

String formatFileSize(AppLocalizations l10n, String locale, int bytes) {
  final format = NumberFormat('0.#', locale);
  if (bytes < 1024) return l10n.group_materialsSizeB('$bytes');
  if (bytes < 1024 * 1024) {
    return l10n.group_materialsSizeKb(format.format(bytes / 1024));
  }
  return l10n.group_materialsSizeMb(format.format(bytes / (1024 * 1024)));
}

Widget _centered(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );

// ---------------------------------------------------------------- group tab

class _GroupMaterialsTab extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final String userId;
  final String? groupId;
  final ValueChanged<Map<String, dynamic>?> onGroupChanged;

  const _GroupMaterialsTab({
    super.key,
    required this.db,
    required this.apiClient,
    required this.userId,
    required this.groupId,
    required this.onGroupChanged,
  });

  @override
  State<_GroupMaterialsTab> createState() => _GroupMaterialsTabState();
}

class _GroupMaterialsTabState extends State<_GroupMaterialsTab>
    with AutomaticKeepAliveClientMixin {
  late final MaterialsRepository _repo = MaterialsRepository(widget.apiClient);
  late final GroupRepository _groups = GroupRepository(widget.apiClient);
  List<GroupMaterial>? _items;
  MaterialsFailure? _error;
  String? _subject;
  final Set<String> _busyIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(useCache: true);
  }

  @override
  void didUpdateWidget(covariant _GroupMaterialsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _items = null;
      _subject = null;
      _load(useCache: true);
    }
  }

  Future<void> _load({bool useCache = false}) async {
    final groupId = widget.groupId;
    if (groupId == null) return;
    setState(() {
      _error = null;
    });
    if (useCache && _items == null) {
      final cached = await _repo.loadCached(groupId);
      if (!mounted) return;
      if (cached != null) setState(() => _items = cached);
    }
    try {
      final fresh = await _repo.fetch(groupId);
      if (!mounted) return;
      setState(() {
        _items = fresh;
        if (_subject != null &&
            !fresh.any((m) => m.subjectTitle == _subject)) {
          _subject = null;
        }
      });
    } on MaterialsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.failure;
      });
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> upload() async {
    final l10n = context.l10n;
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile();
    } catch (_) {
      _snack(l10n.group_materialsUploadFailed);
      return;
    }
    if (file == null || !mounted) return;
    final uploaded = await showUploadMaterialSheet(
      context,
      db: widget.db,
      userId: widget.userId,
      repository: _repo,
      file: file,
    );
    if (uploaded == true && mounted) {
      _snack(l10n.group_materialsUploadDone);
      _load();
    }
  }

  Future<void> _download(GroupMaterial m) async {
    final l10n = context.l10n;
    if (_busyIds.contains(m.id)) return;
    setState(() => _busyIds.add(m.id));
    try {
      final bytes = await _repo.download(m);
      final saved = await FilePicker.saveFile(
        fileName: m.fileName.isEmpty ? m.title : m.fileName,
        bytes: bytes,
      );
      if (saved != null && mounted) _snack(l10n.group_materialsDownloadDone);
    } catch (_) {
      if (mounted) _snack(l10n.group_materialsDownloadFailed);
    } finally {
      if (mounted) setState(() => _busyIds.remove(m.id));
    }
  }

  Future<void> _delete(GroupMaterial m) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.group_materialsDeleteConfirmTitle),
        content: Text(l10n.group_materialsDeleteConfirmMessage(m.title)),
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
            child: Text(l10n.group_materialsDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(m.id);
      if (!mounted) return;
      setState(() => _items = _items?.where((x) => x.id != m.id).toList());
      _snack(l10n.group_materialsDeleteDone);
      _load();
    } on MaterialsException {
      if (mounted) _snack(l10n.group_materialsDeleteFailed);
    }
  }

  Future<void> _joinOrCreate({required bool create}) async {
    final pending =
        create ? null : await GroupRepository.takePendingInviteCode();
    if (!mounted) return;
    final result = create
        ? await showCreateGroupSheet(context, _groups)
        : await showJoinGroupSheet(context, _groups, initialCode: pending);
    if (result?.group != null) widget.onGroupChanged(result!.group);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;

    if (widget.groupId == null) {
      return GroupJoinEmptyState(
        title: l10n.group_materialsNoGroupTitle,
        message: l10n.group_materialsNoGroupMessage,
        onJoin: () => _joinOrCreate(create: false),
        onCreate: () => _joinOrCreate(create: true),
      );
    }

    final items = _items;
    if (items == null) {
      if (_error != null) {
        return _LoadError(
          message: _error == MaterialsFailure.offline
              ? l10n.group_errorOffline
              : l10n.group_materialsLoadFailed,
          onRetry: _load,
        );
      }
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (items.isEmpty && _error == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                title: l10n.group_materialsEmptyTitle,
                message: l10n.group_materialsEmptyMessage,
                actionLabel: l10n.group_materialsUpload,
                onAction: upload,
              ),
            ),
          ),
        ),
      );
    }

    final subjects = {
      for (final m in items)
        if (m.subjectTitle != null) m.subjectTitle!,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final visible = _subject == null
        ? items
        : items.where((m) => m.subjectTitle == _subject).toList();
    final locale = Localizations.localeOf(context).toString();

    return RefreshIndicator(
      onRefresh: _load,
      child: _centered(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_error != null) ...[
              _InlineNotice(
                message: l10n.group_materialsOfflineCached,
                onRetry: _load,
              ),
              const SizedBox(height: 8),
            ],
            if (subjects.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _SubjectChip(
                      label: l10n.group_materialsFilterAll,
                      selected: _subject == null,
                      onTap: () => setState(() => _subject = null),
                    ),
                    for (final s in subjects)
                      _SubjectChip(
                        label: s,
                        selected: _subject == s,
                        onTap: () => setState(() => _subject = s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (visible.isNotEmpty)
              ListGroup(children: [
                for (final m in visible)
                  ListRow(
                    title: m.title.isEmpty ? m.fileName : m.title,
                    subtitle: [
                      ?m.subjectTitle,
                      if (m.uploaderName.isNotEmpty) m.uploaderName,
                      formatFileSize(l10n, locale, m.fileSize),
                    ].join(' · '),
                    onTap: () => _download(m),
                    trailing: _busyIds.contains(m.id)
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _MaterialMenu(
                            canDelete: m.uploaderId == widget.userId,
                            onDownload: () => _download(m),
                            onDelete: () => _delete(m),
                          ),
                  ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

enum _MaterialAction { download, delete }

class _MaterialMenu extends StatelessWidget {
  final bool canDelete;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _MaterialMenu({
    required this.canDelete,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<_MaterialAction>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (action) => switch (action) {
        _MaterialAction.download => onDownload(),
        _MaterialAction.delete => onDelete(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MaterialAction.download,
          child: Text(l10n.group_materialsDownload),
        ),
        if (canDelete)
          PopupMenuItem(
            value: _MaterialAction.delete,
            child: Text(
              l10n.group_materialsDelete,
              style: TextStyle(color: context.palette.danger),
            ),
          ),
      ],
    );
  }
}

/// Quiet one-line notice above content that could not be refreshed.
class _InlineNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineNotice({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message, style: context.text.bodySmall)),
        TextButton(onPressed: onRetry, child: Text(context.l10n.common_retry)),
      ],
    );
  }
}

/// Centered message with a retry button when nothing could be loaded.
class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium!
                  .copyWith(color: context.palette.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.common_retry),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ LMS tab

class _LmsMaterialsTab extends StatelessWidget {
  final AppDatabase db;
  final String userId;
  final OpenUrlFn openUrl;

  const _LmsMaterialsTab({
    required this.db,
    required this.userId,
    required this.openUrl,
  });

  String _typeLabel(AppLocalizations l10n, String type) => switch (type) {
        'file' => l10n.group_materialsTypeFile,
        'folder' => l10n.group_materialsTypeFolder,
        'url' => l10n.group_materialsTypeUrl,
        'page' => l10n.group_materialsTypePage,
        _ => l10n.group_materialsTypeOther,
      };

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.group_materialsLmsOpenFailed;
    final uri = Uri.tryParse(url);
    var ok = false;
    if (uri != null) {
      try {
        ok = await openUrl(uri);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<List<LmsMaterial>>(
      stream: db.lmsDao.watchMaterials(userId),
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (items.isEmpty) {
          return EmptyState(
            title: l10n.group_materialsLmsEmptyTitle,
            message: l10n.group_materialsLmsEmptyMessage,
          );
        }
        final byCourse = <String, List<LmsMaterial>>{};
        for (final m in items) {
          final course = m.courseTitle?.trim();
          byCourse
              .putIfAbsent(
                course == null || course.isEmpty
                    ? l10n.group_materialsLmsNoCourse
                    : course,
                () => [],
              )
              .add(m);
        }
        return _centered(
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              for (final entry in byCourse.entries) ...[
                SectionHeader(entry.key),
                ListGroup(children: [
                  for (final m in entry.value)
                    ListRow(
                      title: m.title,
                      subtitle: [
                        _typeLabel(l10n, m.materialType),
                        if ((m.sectionTitle ?? '').trim().isNotEmpty)
                          m.sectionTitle!.trim(),
                      ].join(' · '),
                      trailing: m.url == null
                          ? null
                          : const Icon(Icons.open_in_new, size: 18),
                      onTap: m.url == null ? null : () => _open(context, m.url!),
                    ),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}
