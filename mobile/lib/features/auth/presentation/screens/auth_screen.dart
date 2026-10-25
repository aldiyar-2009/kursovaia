import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/widgets/server_config_dialog.dart';
import 'package:studyplan/features/main_shell/presentation/screens/main_shell_screen.dart';

class AuthScreen extends StatefulWidget {
  final ApiClient apiClient;
  final AppDatabase db;
  final VoidCallback? onLoginSuccess;

  const AuthScreen({
    super.key,
    required this.apiClient,
    required this.db,
    this.onLoginSuccess,
  });


  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Login controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  // Register controllers
  final _registerFormKey = GlobalKey<FormState>();
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerInviteController = TextEditingController(text: 'AITU26');
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  bool _registerObscure = true;
  bool _registerConfirmObscure = true;

  bool _isLoading = false;
  String? _errorMessage;


  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _errorMessage = null;
        });
      }
    });

  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerInviteController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({String? preEmail, String? prePassword}) async {
    if (preEmail != null && prePassword != null) {
      _loginEmailController.text = preEmail;
      _loginPasswordController.text = prePassword;
    } else {
      if (!_loginFormKey.currentState!.validate()) {
        return;
      }
    }

    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });


    try {
      final response = await widget.apiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
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
      }

      widget.apiClient.updateToken(token);
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, animation, _) => FadeTransition(
              opacity: animation,
              child: MainShellScreen(
                db: widget.db,
                apiClient: widget.apiClient,
                user: user,
                group: group,
              ),
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {

      setState(() {
        if (e is DioException && e.response?.data != null) {
          final errMap = e.response?.data['error'];
          _errorMessage = errMap?['message'] ?? 'Неверный email или пароль';
        } else {
          _errorMessage = 'Не удалось подключиться к серверу';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }

    final name = _registerNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final inviteCode = _registerInviteController.text.trim();
    final password = _registerPasswordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'name': name,
        'email': email,
        'password': password,
        if (inviteCode.isNotEmpty) 'invite_code': inviteCode,
      };

      final response = await widget.apiClient.dio.post('/auth/register', data: payload);
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final group = data['group'] as Map<String, dynamic>?;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_data', jsonEncode(user));
      if (group != null) {
        await prefs.setString('group_data', jsonEncode(group));
      }

      widget.apiClient.updateToken(token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Регистрация успешна! Добро пожаловать в StudyPlan'),
          backgroundColor: AppColors.success,
        ),
      );

      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, animation, _) => FadeTransition(
              opacity: animation,
              child: MainShellScreen(
                db: widget.db,
                apiClient: widget.apiClient,
                user: user,
                group: group,
              ),
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {

      setState(() {
        if (e is DioException && e.response?.data != null) {
          final errMap = e.response?.data['error'];
          final msg = errMap?['message'] ?? 'Ошибка при регистрации';
          if (msg.contains('already registered') || msg.contains('conflict')) {
            _errorMessage = 'Пользователь с таким email уже зарегистрирован';
          } else if (msg.contains('Invite code')) {
            _errorMessage = 'Код группы не найден. Проверьте правильность кода';
          } else {
            _errorMessage = msg;
          }
        } else {
          _errorMessage = 'Ошибка сети или соединения с сервером';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              color: AppColors.surface,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.border, width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.accent, AppColors.accentCyan],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.settings_ethernet_rounded, size: 20, color: AppColors.textMuted),
                            tooltip: 'Настройка подключения к API',
                            onPressed: () => ServerConfigDialog.show(context, widget.apiClient),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'StudyPlan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Единое студенческое пространство',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tab Selector: Вход / Регистрация
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        tabs: const [
                          Tab(text: 'Вход'),
                          Tab(text: 'Регистрация'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error Message Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.plate(AppColors.danger, 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tab Views
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: [
                        _buildLoginForm(),
                        _buildRegisterForm(),
                      ][_tabController.index],
                    ),

                    const SizedBox(height: 24),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),

                    // Demo Accounts Quick Fill
                    const Text(
                      'Тестовый вход без ввода пароля:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                              foregroundColor: AppColors.accent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: const BorderSide(color: AppColors.accent, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.school_rounded, size: 16),
                            label: const Text('Студент', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            onPressed: _isLoading
                                ? null
                                : () => _handleLogin(
                                      preEmail: 'student@studyplan.dev',
                                      prePassword: 'password123',
                                    ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.badge_rounded, size: 16, color: AppColors.accentCyan),
                            label: const Text('Староста', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                            onPressed: _isLoading
                                ? null
                                : () => _handleLogin(
                                      preEmail: 'headman@studyplan.dev',
                                      prePassword: 'password123',
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- LOGIN FORM ---
  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'example@university.edu',
              prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppColors.textSecondary),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите email';
              }
              if (!_emailRegex.hasMatch(value.trim())) {
                return 'Некорректный формат email';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _loginObscure,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _loginObscure = !_loginObscure),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите пароль';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _handleLogin(),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Войти в систему'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _tabController.animateTo(1);
            },
            child: const Text(
              'Еще нет аккаунта? Зарегистрироваться',
              style: TextStyle(color: AppColors.accentCyan, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // --- REGISTER FORM ---
  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _registerNameController,
            decoration: const InputDecoration(
              labelText: 'Имя и Фамилия',
              hintText: 'Алихан Даулетов',
              prefixIcon: Icon(Icons.person_outline, size: 20, color: AppColors.textSecondary),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите ваше имя и фамилию';
              }
              if (value.trim().length < 2) {
                return 'Имя слишком короткое';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'student@studyplan.dev',
              prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppColors.textSecondary),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите email';
              }
              if (!_emailRegex.hasMatch(value.trim())) {
                return 'Некорректный формат email (пример: user@domain.com)';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerInviteController,
            decoration: const InputDecoration(
              labelText: 'Код группы (приглашение)',
              hintText: 'Например, IVT21A',
              prefixIcon: Icon(Icons.group_outlined, size: 20, color: AppColors.textSecondary),
              helperText: 'Код группы выдается старостой (для демо: IVT21A)',
              helperStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _registerObscure,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _registerObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _registerObscure = !_registerObscure),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите пароль';
              }
              if (value.length < 6) {
                return 'Пароль должен содержать минимум 6 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _registerConfirmPasswordController,
            obscureText: _registerConfirmObscure,
            decoration: InputDecoration(
              labelText: 'Подтвердите пароль',
              prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20, color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _registerConfirmObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _registerConfirmObscure = !_registerConfirmObscure),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Повторите пароль';
              }
              if (value != _registerPasswordController.text) {
                return 'Пароли не совпадают';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleRegister(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Зарегистрироваться'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _tabController.animateTo(0);
            },
            child: const Text(
              'Уже зарегистрированы? Войти',
              style: TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
