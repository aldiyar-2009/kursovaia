import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/features/lms/data/lms_importer.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Outcome of an import: what was saved, what failed, retry and done.
class LmsImportResultView extends StatelessWidget {
  const LmsImportResultView({
    super.key,
    required this.summary,
    required this.onRetry,
    required this.onDone,
  });

  final LmsImportSummary summary;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  static String kindLabel(AppLocalizations l, String kind) => switch (kind) {
        'courses' => l.lms_kindCourses,
        'grades' => l.lms_kindGrades,
        'deadlines' => l.lms_kindDeadlines,
        'classes' => l.lms_kindSchedule,
        'materials' => l.lms_kindMaterials,
        'profile' => l.lms_kindProfile,
        _ => kind,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final t = context.text;
    final partial = summary.errors.isNotEmpty;
    final deadlines = summary.events - summary.classes;

    final counts = <(String, int)>[
      (l.lms_countCourses, summary.courses),
      (l.lms_countDeadlines, deadlines < 0 ? 0 : deadlines),
      (l.lms_countClasses, summary.classes),
      (l.lms_countMaterials, summary.materials),
    ];

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Text(
                  partial ? l.lms_resultPartialTitle : l.lms_resultTitle,
                  style: t.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  partial ? l.lms_resultPartialLead : l.lms_resultLead,
                  style: t.bodyMedium!.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: 24),
                _Group(
                  children: [
                    for (final (label, value) in counts)
                      _CountRow(label: label, value: value),
                  ],
                ),
                if (partial) ...[
                  const SizedBox(height: 24),
                  Text(
                    l.lms_errorsHeader,
                    style: t.labelMedium!.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _Group(
                    children: [
                      for (final e in summary.errors.entries)
                        _ErrorRow(
                          label: kindLabel(l, e.key),
                          detail: e.value,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (partial) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: Text(l.lms_retry),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: onDone,
                    child: Text(l.lms_done),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows on a surface with a 1 px outline and hairline separators.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: p.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          Text(
            '$value',
            style: t.titleSmall!.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: p.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodyMedium),
                if (detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall!.copyWith(color: p.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
