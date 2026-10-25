import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

enum StatusTone { neutral, success, warning, danger }

/// Compact status text on a muted background (radius 4).
/// Colour carries meaning only: passed / at risk / failed.
class StatusLabel extends StatelessWidget {
  final String text;
  final StatusTone tone;

  const StatusLabel({super.key, required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg) = switch (tone) {
      StatusTone.neutral => (p.textSecondary, p.surfaceMuted),
      StatusTone.success => (p.success, p.successMuted),
      StatusTone.warning => (p.warning, p.warningMuted),
      StatusTone.danger => (p.danger, p.dangerMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelSmall!.copyWith(color: fg),
      ),
    );
  }
}
