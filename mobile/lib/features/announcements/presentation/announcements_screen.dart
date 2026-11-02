import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/content_column.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/announcements/data/announcements_repository.dart';

/// All published announcements, newest first; pull to refresh.
class AnnouncementsScreen extends StatefulWidget {
  final AnnouncementsRepository repository;

  const AnnouncementsScreen({super.key, required this.repository});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  AnnouncementsResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.repository.load();
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    return Scaffold(
      appBar: ContentAppBar(title: Text(l10n.announcements_title)),
      body: result == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: result.items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          title: l10n.announcements_emptyTitle,
                          message: result.fromCache
                              ? l10n.announcements_offline
                              : l10n.announcements_emptyMessage,
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        padding: contentPadding(
                          constraints.maxWidth,
                          bottom: 32,
                        ),
                        children: [
                          if (result.fromCache)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                              child: Text(
                                l10n.announcements_offline,
                                style: context.text.bodySmall!.copyWith(
                                  color: context.palette.warning,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          ListGroup(
                            children: [
                              for (final a in result.items)
                                AnnouncementRow(announcement: a),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }
}

/// Title, date and full text of one announcement.
class AnnouncementRow extends StatelessWidget {
  final Announcement announcement;

  /// Lines of the body shown; null shows everything.
  final int? maxLines;
  final VoidCallback? onTap;

  const AnnouncementRow({
    super.key,
    required this.announcement,
    this.maxLines,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final date = announcement.publishedAt;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: context.text.titleSmall,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    DateFormat.MMMd(locale).format(date),
                    style: context.text.labelSmall!.copyWith(
                      color: p.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              announcement.body,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: context.text.bodyMedium!.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
