import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/empty_state.dart';
import 'package:studyplan/features/auth/data/session_service.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/auth/presentation/screens/edition_choice_screen.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

/// Dependencies every account action needs (passed down from `main.dart`).
class AppDeps {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;

  const AppDeps({
    required this.db,
    required this.apiClient,
    required this.settings,
  });
}

/// Replaces the whole navigation stack with the shell of [session], or with
/// the guest shell when [session] is null.
void openShell(BuildContext context, AppDeps deps, {Session? session}) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: animation,
        child: MainShellScreen(
          db: deps.db,
          apiClient: deps.apiClient,
          settings: deps.settings,
          user: session?.user ?? guestUser(),
          group: session?.group,
        ),
      ),
    ),
    (route) => false,
  );
}

/// Replaces the whole navigation stack with the «university or college»
/// choice (first start, after logout).
void openStart(BuildContext context, AppDeps deps) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: animation,
        child: EditionChoiceScreen(deps: deps),
      ),
    ),
    (route) => false,
  );
}

/// Opens sign-in (or sign-up) of the chosen edition on top of the current
/// screen.
void openSignIn(BuildContext context, AppDeps deps, {bool signUp = false}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => AuthScreen(
        apiClient: deps.apiClient,
        db: deps.db,
        settings: deps.settings,
        edition: deps.settings.edition ?? AppEdition.university,
        startWithSignUp: signUp,
      ),
    ),
  );
}

/// Creates a demo account of the chosen edition on the server and opens it.
/// Shows a snackbar and returns false when the server cannot be reached.
Future<bool> startDemo(BuildContext context, AppDeps deps) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failedText = context.l10n.guest_demoFailed;
  try {
    final session = await requestDemoSession(
      deps.apiClient,
      edition: deps.settings.edition ?? AppEdition.university,
    );
    await startSession(session, db: deps.db, apiClient: deps.apiClient);
    if (!context.mounted) return true;
    openShell(context, deps, session: session);
    return true;
  } on DioException catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(failedText)));
    return false;
  }
}

/// Shown instead of server-only screens (group, shared materials) in guest
/// mode.
class AccountRequiredScreen extends StatefulWidget {
  final String title;
  final AppDeps deps;

  const AccountRequiredScreen({
    super.key,
    required this.title,
    required this.deps,
  });

  @override
  State<AccountRequiredScreen> createState() => _AccountRequiredScreenState();
}

class _AccountRequiredScreenState extends State<AccountRequiredScreen> {
  bool _busy = false;

  Future<void> _demo() async {
    setState(() => _busy = true);
    final ok = await startDemo(context, widget.deps);
    if (!ok && mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : EmptyState(
              title: l10n.guest_requiredTitle,
              message: l10n.guest_requiredMessage,
              actionLabel: l10n.guest_signIn,
              onAction: () => openSignIn(context, widget.deps),
              secondaryLabel: l10n.auth_tryDemo,
              onSecondary: _demo,
            ),
    );
  }
}
