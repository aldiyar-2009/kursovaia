import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/features/auth/presentation/screens/auth_screen.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  String _statusText = 'Инициализация модулей...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Stage 1: Short delay for splash branding
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _statusText = 'Проверка сохраненной сессии...';
    });

    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString('api_base_url');
    if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
      if (kIsWeb && savedBaseUrl.contains('127.0.0.1') && !Uri.base.origin.contains('127.0.0.1')) {
        widget.apiClient.updateBaseUrl(ApiClient.defaultBaseUrl);
      } else {
        widget.apiClient.updateBaseUrl(savedBaseUrl.trim());
      }
    } else {
      widget.apiClient.updateBaseUrl(ApiClient.defaultBaseUrl);
    }
    final token = prefs.getString('jwt_token');
    final userData = prefs.getString('user_data');
    final groupData = prefs.getString('group_data');

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    if (token != null && userData != null) {
      widget.apiClient.updateToken(token);
      final user = jsonDecode(userData) as Map<String, dynamic>;
      final group = groupData != null ? jsonDecode(groupData) as Map<String, dynamic> : null;

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
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: target,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Logo container
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 36,
                        spreadRadius: 6,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'StudyPlan',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Персональный учебный ассистент',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading indicator & status
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Курсовой проект • v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
