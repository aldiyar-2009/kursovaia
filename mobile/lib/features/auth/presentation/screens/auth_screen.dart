import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/server_config_dialog.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';
import 'package:studyplan/core/widgets/ui/segmented_toggle.dart';
import 'package:studyplan/features/auth/data/session_service.dart';
import 'package:studyplan/features/auth/presentation/account_actions.dart';

enum _AuthMode { signIn, signUp }

/// Sign-in / sign-up. The invite code is prefilled only from a pending
/// invite link (SharedPreferences `pending_invite_code`).
class AuthScreen extends StatefulWidget {
  final ApiClient apiClient;
  final AppDatabase db;
  final AppSettings settings;
  final VoidCallback? onLoginSuccess;

  /// University: email account (sign-in / sign-up). College: SmartNation
  /// login (ИИН or login) and password, no separate registration.
  final AppEdition edition;

  /// Opens on the sign-up form instead of sign-in.
  final bool startWithSignUp;

  const AuthScreen({
    super.key,
    required this.apiClient,
    required this.db,
    required this.settings,
    this.onLoginSuccess,
    this.edition = AppEdition.university,
    this.startWithSignUp = false,
  });

  /// SharedPreferences key of an invite code taken from a `/join/<code>` link.
  static const pendingInviteKey = 'pending_invite_code';

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late _AuthMode _mode = widget.startWithSignUp && !_college
      ? _AuthMode.signUp
      : _AuthMode.signIn;

  bool get _college => widget.edition.isCollege;
  bool _demoLoading = false;

  AppDeps get _deps => AppDeps(
    db: widget.db,
    apiClient: widget.apiClient,
    settings: widget.settings,
  );

  // Replaced on mode switch so stale validation errors disappear.
  var _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _inviteController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _errorMessage;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    _loadPendingInvite();
  }

  Future<void> _loadPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AuthScreen.pendingInviteKey)?.trim();
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _inviteController.text = code);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _formKey = GlobalKey<FormState>();
    });
  }

  String _errorFor(Object e) {
    final l10n = context.l10n;
    if (e is DioException) {
      final response = e.response;
      if (response == null) return l10n.auth_errorNetwork;
      final data = response.data;
      final message = data is Map ? '${data['error']?['message'] ?? ''}' : '';
      final code = apiErrorCode(e);
      if (code == 'USER_BLOCKED') return l10n.auth_errorBlocked;
      if (code == 'SN_INVALID_CREDENTIALS') {
        return l10n.college_errorCredentials;
      }
      if (code == 'SN_UNAVAILABLE') return l10n.college_errorPortal;
      if (message.contains('Invite code')) return l10n.auth_errorInviteCode;
      if (response.statusCode == 409) return l10n.auth_errorEmailTaken;
      if (response.statusCode == 401) return l10n.auth_errorInvalidCredentials;
    }
    return l10n.auth_errorGeneric;
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final signUp = _mode == _AuthMode.signUp;
    final inviteCode = _inviteController.text.trim();
    try {
      final Session session;
      if (_college) {
        session = await requestCollegeSession(
          widget.apiClient,
          login: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        final response = signUp
            ? await widget.apiClient.dio.post(
                '/auth/register',
                data: {
                  'name': _nameController.text.trim(),
                  'email': _emailController.text.trim(),
                  'password': _passwordController.text,
                  if (inviteCode.isNotEmpty) 'invite_code': inviteCode,
                },
              )
            : await widget.apiClient.dio.post(
                '/auth/login',
                data: {
                  'email': _emailController.text.trim(),
                  'password': _passwordController.text,
                },
              );

        session = Session.fromJson(response.data as Map<String, dynamic>);
      }
      // Pulls everything for this account from scratch (including group tasks
      // published before a sign-up with an invite code) and hands over what
      // was entered in guest mode; the shell starts the sync right away.
      await startSession(session, db: widget.db, apiClient: widget.apiClient);
      if (session.group != null && signUp && inviteCode.isNotEmpty) {
        // The pending invite has been used to join this group.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AuthScreen.pendingInviteKey);
      }

      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
        return;
      }
      if (!mounted) return;
      openShell(context, _deps, session: session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorFor(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _demo() async {
    if (_demoLoading || _isLoading) return;
    setState(() {
      _demoLoading = true;
      _errorMessage = null;
    });
    final ok = await startDemo(context, _deps);
    if (!ok && mounted) setState(() => _demoLoading = false);
  }

  /// The app in guest mode: data stays on the device; the next start opens
  /// the guest shell again instead of the edition choice.
  Future<void> _continueAsGuest() async {
    await setGuestMode(true);
    if (!mounted) return;
    openShell(context, _deps);
  }

  /// Switches to the sign-in of the other edition.
  Future<void> _switchEdition() async {
    final other = _college ? AppEdition.university : AppEdition.college;
    await widget.settings.setEdition(other);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(
          apiClient: widget.apiClient,
          db: widget.db,
          settings: widget.settings,
          edition: other,
          onLoginSuccess: widget.onLoginSuccess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final signUp = _mode == _AuthMode.signUp;
    final busy = _isLoading || _demoLoading;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: Navigator.of(context).canPop()
          ? AppBar(backgroundColor: palette.background)
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _college
                            ? l10n.college_signInTitle
                            : l10n.edition_university,
                        style: context.text.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _college ? l10n.college_signInHint : l10n.auth_tagline,
                        style: context.text.bodyMedium!.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!_college) ...[
                        SegmentedToggle<_AuthMode>(
                          key: const ValueKey('auth_mode'),
                          expand: true,
                          height: 44,
                          segments: [
                            (_AuthMode.signIn, l10n.auth_signIn),
                            (_AuthMode.signUp, l10n.auth_signUp),
                          ],
                          value: _mode,
                          onChanged: _setMode,
                        ),
                        const SizedBox(height: 24),
                      ],
                      ..._fields(signUp),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBox(message: _errorMessage!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const ValueKey('auth_submit'),
                        onPressed: busy ? null : _submit,
                        child: _isLoading
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.textSecondary,
                                ),
                              )
                            : Text(
                                signUp
                                    ? l10n.auth_submitSignUp
                                    : l10n.auth_submitSignIn,
                              ),
                      ),
                      if (_college) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.college_passwordNote,
                          style: context.text.bodySmall!.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton(
                        key: const ValueKey('auth_demo'),
                        onPressed: busy ? null : _demo,
                        child: _demoLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.auth_tryDemo),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _college ? l10n.college_demoHint : l10n.auth_demoHint,
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall!.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('auth_guest'),
                        onPressed: busy ? null : _continueAsGuest,
                        child: Text(l10n.auth_continueAsGuest),
                      ),
                      TextButton(
                        key: const ValueKey('auth_switch_edition'),
                        onPressed: busy ? null : _switchEdition,
                        child: Text(
                          _college
                              ? l10n.edition_switchToUniversity
                              : l10n.edition_switchToCollege,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textSecondary,
                          ),
                          onPressed: () => ServerConfigDialog.show(
                            context,
                            widget.apiClient,
                          ),
                          child: Text(l10n.auth_serverSettings),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(bool signUp) {
    final l10n = context.l10n;
    final visibility = IconButton(
      tooltip: _obscure ? l10n.auth_showPassword : l10n.auth_hidePassword,
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    final confirmVisibility = IconButton(
      key: const ValueKey('auth_confirm_visibility'),
      tooltip: _obscureConfirm
          ? l10n.auth_showPasswordRepeat
          : l10n.auth_hidePasswordRepeat,
      icon: Icon(
        _obscureConfirm
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 20,
      ),
      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
    );

    const gap = SizedBox(height: 16);
    return [
      if (signUp) ...[
        AppTextField(
          key: const ValueKey('auth_name'),
          controller: _nameController,
          label: l10n.auth_name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          validator: (v) => (v == null || v.trim().length < 2)
              ? l10n.auth_errorNameRequired
              : null,
        ),
        gap,
      ],
      AppTextField(
        key: const ValueKey('auth_email'),
        controller: _emailController,
        label: _college ? l10n.college_login : l10n.auth_email,
        keyboardType: _college
            ? TextInputType.text
            : TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: [
          _college ? AutofillHints.username : AutofillHints.email,
        ],
        validator: (v) {
          final value = v?.trim() ?? '';
          if (_college) {
            return value.isEmpty ? l10n.college_errorLoginRequired : null;
          }
          if (value.isEmpty) return l10n.auth_errorEmailRequired;
          if (!_emailRegex.hasMatch(value)) return l10n.auth_errorEmailInvalid;
          return null;
        },
      ),
      gap,
      AppTextField(
        key: const ValueKey('auth_password'),
        controller: _passwordController,
        label: l10n.auth_password,
        obscureText: _obscure,
        suffix: visibility,
        textInputAction: signUp ? TextInputAction.next : TextInputAction.done,
        autofillHints: [
          signUp ? AutofillHints.newPassword : AutofillHints.password,
        ],
        validator: (v) {
          if (v == null || v.isEmpty) return l10n.auth_errorPasswordRequired;
          if (signUp && v.length < 6) return l10n.auth_errorPasswordShort;
          return null;
        },
        onSubmitted: signUp ? null : (_) => _submit(),
      ),
      if (signUp) ...[
        gap,
        AppTextField(
          key: const ValueKey('auth_confirm'),
          controller: _confirmController,
          label: l10n.auth_passwordRepeat,
          obscureText: _obscureConfirm,
          suffix: confirmVisibility,
          textInputAction: TextInputAction.next,
          validator: (v) => v != _passwordController.text
              ? l10n.auth_errorPasswordMismatch
              : null,
        ),
        gap,
        AppTextField(
          key: const ValueKey('auth_invite'),
          controller: _inviteController,
          label: l10n.auth_inviteCode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ],
    ];
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.dangerMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          message,
          style: context.text.bodySmall!.copyWith(color: palette.danger),
        ),
      ),
    );
  }
}
