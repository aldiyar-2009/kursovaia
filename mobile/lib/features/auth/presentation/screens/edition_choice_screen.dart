import 'package:flutter/material.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/server_config_dialog.dart';
import 'package:studyplan/core/widgets/ui/list_row.dart';
import 'package:studyplan/features/auth/presentation/account_actions.dart';

/// First screen without a session: «university student» or «college
/// student». The choice decides how the user signs in (email or SmartNation)
/// and which features the app shows.
class EditionChoiceScreen extends StatelessWidget {
  final AppDeps deps;

  const EditionChoiceScreen({super.key, required this.deps});

  Future<void> _choose(BuildContext context, AppEdition edition) async {
    await deps.settings.setEdition(edition);
    if (!context.mounted) return;
    openSignIn(context, deps);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.common_appName, style: context.text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    l10n.auth_tagline,
                    style: context.text.bodyMedium!.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(l10n.edition_question, style: context.text.titleSmall),
                  const SizedBox(height: 12),
                  ListGroup(
                    children: [
                      ListRow(
                        key: const ValueKey('edition_university'),
                        leading: const Icon(Icons.account_balance_outlined),
                        title: l10n.edition_university,
                        subtitle: l10n.edition_universityHint,
                        trailing: const ListRowChevron(),
                        onTap: () => _choose(context, AppEdition.university),
                      ),
                      ListRow(
                        key: const ValueKey('edition_college'),
                        leading: const Icon(Icons.school_outlined),
                        title: l10n.edition_college,
                        subtitle: l10n.edition_collegeHint,
                        trailing: const ListRowChevron(),
                        onTap: () => _choose(context, AppEdition.college),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textSecondary,
                      ),
                      onPressed: () =>
                          ServerConfigDialog.show(context, deps.apiClient),
                      child: Text(l10n.auth_serverSettings),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
