import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/database/task_dao.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/utils/open_url.dart';
import 'package:studyplan/core/widgets/ui/app_sheet.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/events/data/events_repository.dart';

/// Events from the public Telegram channel: upcoming / past, with
/// registration links and «add to my plan» (a personal task).
class EventsScreen extends StatefulWidget {
  final AppDatabase db;
  final EventsRepository repository;
  final String userId;

  const EventsScreen({
    super.key,
    required this.db,
    required this.repository,
    required this.userId,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _past = false;
  EventsResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await widget.repository.load(past: _past);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  void _setPast(bool past) {
    if (past == _past) return;
    _past = past;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: ContentAppBar(
        title: Text(l10n.events_title),
        actions: [
          IconButton(
            tooltip: l10n.events_refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final inset = contentInset(constraints.maxWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SegmentedToggle<bool>(
                      expand: true,
                      segments: [
                        (false, l10n.events_upcoming),
                        (true, l10n.events_past),
                      ],
                      value: _past,
                      onChanged: _setPast,
                    ),
                  ),
                ),
              ),
              Expanded(child: _body(context, constraints.maxWidth)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, double width) {
    final l10n = context.l10n;
    final result = _result;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result.events.isEmpty) {
      return EmptyState(
        title: _past ? l10n.events_emptyPastTitle : l10n.events_emptyTitle,
        message: result.fromCache
            ? l10n.events_offline
            : l10n.events_emptyMessage,
        actionLabel: l10n.events_refresh,
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: contentPadding(width, top: 8, bottom: 32),
        children: [
          if (result.fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.events_offline, style: context.text.bodySmall),
            ),
          EventList(
            db: widget.db,
            userId: widget.userId,
            events: result.events,
            allowAdd: !_past,
          ),
        ],
      ),
    );
  }
}

/// Rows of events with the «in plan» state; also used by the Home block.
class EventList extends StatelessWidget {
  final AppDatabase db;
  final String userId;
  final List<CampusEvent> events;
  final bool allowAdd;

  const EventList({
    super.key,
    required this.db,
    required this.userId,
    required this.events,
    this.allowAdd = true,
  });

  @override
  Widget build(BuildContext context) {
    final dao = TaskDao(db);
    return StreamBuilder<Set<String>>(
      stream: dao.watchExistingIds(events.map((e) => e.taskId(userId))),
      builder: (context, snap) {
        final added = snap.data ?? const <String>{};
        return ListGroup(
          dividerIndent: 72,
          children: [
            for (final e in events)
              _EventRow(
                event: e,
                inPlan: added.contains(e.taskId(userId)),
                onTap: () =>
                    showEventDetails(context, db: db, userId: userId, event: e),
                onAdd: allowAdd
                    ? () => addEventToPlan(context, db, userId, e)
                    : null,
              ),
          ],
        );
      },
    );
  }
}

/// Creates the personal task for [event]; a snackbar confirms.
Future<void> addEventToPlan(
  BuildContext context,
  AppDatabase db,
  String userId,
  CampusEvent event,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final details = [
    if (event.place != null && event.place!.isNotEmpty) event.place!,
    if (event.link != null && event.link!.isNotEmpty) event.link!,
  ].join('\n');
  final added = await TaskDao(db).addExternalTask(
    id: event.taskId(userId),
    userId: userId,
    title: event.title,
    description: details.isEmpty ? null : details,
    due: event.planDate,
    priority: 3,
  );
  messenger?.showSnackBar(
    SnackBar(
      content: Text(added ? l10n.events_added : l10n.events_alreadyAdded),
    ),
  );
}

String _when(BuildContext context, CampusEvent e) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final day = DateFormat('d MMMM, EEEE', locale).format(e.startsAt);
  return e.hasTime ? '$day, ${DateFormat.Hm(locale).format(e.startsAt)}' : day;
}

Future<void> showEventDetails(
  BuildContext context, {
  required AppDatabase db,
  required String userId,
  required CampusEvent event,
}) {
  final l10n = context.l10n;
  final upcoming = event.planDate.isAfter(DateTime.now());
  return showAppSheet<void>(
    context,
    title: event.title,
    primaryAction: upcoming
        ? FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await addEventToPlan(context, db, userId, event);
            },
            child: Text(l10n.events_addToPlan),
          )
        : null,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_when(sheetContext, event), style: sheetContext.text.labelLarge),
        if (event.place != null && event.place!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(event.place!, style: sheetContext.text.bodySmall),
        ],
        if (event.text != null && event.text!.isNotEmpty) ...[
          const SizedBox(height: 16),
          SelectableText(event.text!, style: sheetContext.text.bodyMedium),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (event.link != null && event.link!.isNotEmpty)
              OutlinedButton(
                onPressed: () => openExternalUrl(sheetContext, event.link),
                child: Text(l10n.events_register),
              ),
            if (event.postUrl != null && event.postUrl!.isNotEmpty)
              OutlinedButton(
                onPressed: () => openExternalUrl(sheetContext, event.postUrl),
                child: Text(l10n.events_openPost),
              ),
          ],
        ),
      ],
    ),
  );
}

class _EventRow extends StatelessWidget {
  final CampusEvent event;
  final bool inPlan;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _EventRow({
    required this.event,
    required this.inPlan,
    required this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final details = [
      if (event.hasTime) DateFormat.Hm(locale).format(event.startsAt),
      if (event.place != null && event.place!.isNotEmpty) event.place!,
    ].join(' · ');
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Text(
                      '${event.startsAt.day}',
                      style: context.text.titleSmall!.tabular,
                    ),
                    Text(
                      DateFormat('MMM', locale).format(event.startsAt),
                      maxLines: 1,
                      style: context.text.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (inPlan)
                StatusLabel(text: l10n.events_inPlan, tone: StatusTone.success)
              else if (onAdd != null)
                IconButton(
                  tooltip: l10n.events_addToPlan,
                  icon: const Icon(Icons.add_task_outlined, size: 20),
                  onPressed: onAdd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
