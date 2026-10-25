import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';

/// Group screen. Placeholder until the group feature (members, invite,
/// materials) is rebuilt.
class GroupScreen extends StatelessWidget {
  final Map<String, dynamic>? group;

  const GroupScreen({super.key, this.group});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = group?['title'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text(title ?? l10n.nav_group)),
      body: EmptyState(
        title: title ?? l10n.nav_groupEmptyTitle,
        message: l10n.nav_groupEmptyMessage,
      ),
    );
  }
}
