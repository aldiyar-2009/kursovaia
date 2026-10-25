import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/theme_ext.dart';

/// Small secondary heading above a group of rows.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.text.labelMedium!
                  .copyWith(color: context.palette.textSecondary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
