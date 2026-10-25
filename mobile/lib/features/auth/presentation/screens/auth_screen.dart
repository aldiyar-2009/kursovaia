import 'dart:convert';

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
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

enum _AuthMode { signIn, signUp }

/// Sign-in / sign-up. The invite code is prefilled only from a pending
/// invite link (SharedPreferences `pending_invite_code`).
class AuthScreen extends StatefulWidget {
  final ApiClient apiClient;
  final AppDatabase db;
  final AppSettings settings;
  final VoidCallback? onLoginSuccess;

  const AuthScreen({
    super.key,
    required this.apiClient,
    required this.db,
    required this.settings,
    this.onLoginSuccess,
  });

  /// SharedPreferences key of an invite code taken from a `/join/<code>` link.
  static const pendingInviteKey = 'pending_invite_code';

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthMode _mode = _AuthMode.signIn;

  // Replaced on mode switch so stale validation errors disappear.
  var _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _inviteController = TextEditingController();
  bool _obscure = true;

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
      final response = signUp
          ? await widget.apiClient.dio.post('/auth/register', data: {
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
              if (inviteCode.isNotEmpty) 'invite_code': inviteCode,
            })
          : await widget.apiClient.dio.post('/auth/login', data: {
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            });

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final group = data['group'] as Map<String, dynamic>?;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_data', jsonEncode(user));
      if (group != null) {
        await prefs.setString('group_data', jsonEncode(group));
        // The pending invite has been used to join this group.
        if (signUp && inviteCode.isNotEmpty) {
          await prefs.remove(AuthScreen.pendingInviteKey);
        }
      }
      widget.apiClient.updateToken(token);

      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
        return;
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: MainShellScreen(
              db: widget.db,
              apiClient: widget.apiClient,
              settings: widget.settings,
              user: user,
              group: group,
            ),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorFor(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final signUp = _mode == _AuthMode.signUp;

    return Scaffold(
      backgroundColor: palette.background,
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
                      Text(l10n.common_appName, style: context.text.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        l10n.auth_tagline,
                        style: context.text.bodyMedium!
                            .copyWith(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      SegmentedButton<_AuthMode>(
                        showSelectedIcon: false,
                        expandedInsets: EdgeInsets.zero,
                        segments: [
                          ButtonSegment(
                            value: _AuthMode.signIn,
                            label: Text(l10n.auth_signIn),
                          ),
                          ButtonSegment(
                            value: _AuthMode.signUp,
                            label: Text(l10n.auth_signUp),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) => _setMode(s.first),
                      ),
                      const SizedBox(height: 24),
                      ..._fields(signUp),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBox(message: _errorMessage!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.textSecondary,
                                ),
                              )
                            : Text(signUp
                                ? l10n.auth_submitSignUp
                                : l10n.auth_submitSignIn),
                      ),
                      const SizedBox(height: 24),
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
        label: l10n.auth_email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        validator: (v) {
          final value = v?.trim() ?? '';
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
        textInputAction:
            signUp ? TextInputAction.next : TextInputAction.done,
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
          obscureText: _obscure,
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
