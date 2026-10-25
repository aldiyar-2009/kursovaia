import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/status_label.dart';
import 'package:studyplan/features/home/domain/home_agenda.dart';
import 'package:studyplan/features/home/presentation/widgets/home_rows.dart';

/// The current or next lesson: the one emphasised block on Home.
/// A muted surface, no border or shadow; an ongoing lesson shows a thin
/// line of elapsed time.
class NowBlock extends StatelessWidget {
  final AgendaLesson lesson;
  final DateTime now;

  const NowBlock({super.key, required this.lesson, required this.now});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final ongoing = lesson.isOngoing(now);

    final String countdown;
    if (ongoing) {
      countdown = l10n.home_minutesLeft(_ceilMinutes(lesson.end.difference(now)));
    } else {
      final minutes = _ceilMinutes(lesson.start.difference(now));
      countdown = minutes < 60
          ? l10n.home_startsInMinutes(minutes)
          : l10n.home_startsInHours(minutes ~/ 60, minutes % 60);
    }

    final meta = lessonMeta(context, lesson);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ongoing ? l10n.home_now : l10n.home_next,
                  style: context.text.labelMedium,
                ),
              ),
              Text(
                countdown,
                style: context.text.labelMedium!.tabular,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lesson.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                timeRange(context, lesson),
                style: context.text.bodyMedium!
                    .copyWith(color: p.textPrimary, fontWeight: FontWeight.w500)
                    .tabular,
              ),
              if (meta != null)
                Text(
                  meta,
                  style: context.text.bodyMedium!
                      .copyWith(color: p.textSecondary),
                ),
              if (lesson.fromLms)
                StatusLabel(text: l10n.home_sourceLms, tone: StatusTone.neutral),
            ],
          ),
          if (ongoing) ...[
            const SizedBox(height: 14),
            _Elapsed(fraction: _fraction()),
          ],
        ],
      ),
    );
  }

  double _fraction() {
    final total = lesson.end.difference(lesson.start).inSeconds;
    if (total <= 0) return 1;
    final done = now.difference(lesson.start).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }

  static int _ceilMinutes(Duration d) {
    final seconds = d.inSeconds;
    if (seconds <= 0) return 0;
    return (seconds + 59) ~/ 60;
  }
}

class _Elapsed extends StatelessWidget {
  final double fraction;

  const _Elapsed({required this.fraction});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: SizedBox(
        height: 2,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.border)),
            FractionallySizedBox(
              widthFactor: fraction,
              heightFactor: 1,
              child: ColoredBox(color: p.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
