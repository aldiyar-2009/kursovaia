import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

/// Wordmark on the page background while the saved session is restored.
class SplashScreen extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;

  const SplashScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString('api_base_url')?.trim();
    if (savedBaseUrl != null && savedBaseUrl.isNotEmpty) {
      final staleLocalhost = kIsWeb &&
          savedBaseUrl.contains('127.0.0.1') &&
          !Uri.base.origin.contains('127.0.0.1');
      widget.apiClient.updateBaseUrl(
        staleLocalhost ? ApiClient.defaultBaseUrl : savedBaseUrl,
      );
    } else {
      widget.apiClient.updateBaseUrl(ApiClient.defaultBaseUrl);
    }

    final token = prefs.getString('jwt_token');
    final userData = prefs.getString('user_data');
    final groupData = prefs.getString('group_data');
    if (!mounted) return;

    if (token != null && userData != null) {
      widget.apiClient.updateToken(token);
      final user = jsonDecode(userData) as Map<String, dynamic>;
      final group = groupData != null
          ? jsonDecode(groupData) as Map<String, dynamic>
          : null;
      _navigateTo(
        MainShellScreen(
          db: widget.db,
          apiClient: widget.apiClient,
          settings: widget.settings,
          user: user,
          group: group,
        ),
      );
    } else {
      _navigateTo(
        AuthScreen(
          apiClient: widget.apiClient,
          settings: widget.settings,
          db: widget.db,
        ),
      );
    }
  }

  void _navigateTo(Widget target) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: target),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: Center(
        child: Text(
          context.l10n.common_appName,
          style: context.text.headlineMedium,
        ),
      ),
    );
  }
}
