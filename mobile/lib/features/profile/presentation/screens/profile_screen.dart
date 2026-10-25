import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/theme/app_colors.dart';
import 'package:studyplan/core/widgets/server_config_dialog.dart';


class ProfileScreen extends StatefulWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? group;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>>? onUserUpdated;

  const ProfileScreen({
    super.key,
    required this.db,
    required this.apiClient,
    required this.user,
    this.group,
    required this.onLogout,
    this.onUserUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _currentUser;
  bool _isEditing = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _nameController.text = _currentUser['name'] as String? ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      final res = await widget.apiClient.dio.patch('/auth/me', data: {'name': newName});
      final data = res.data as Map<String, dynamic>;
      final updatedUser = data['user'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(updatedUser));

      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
      });

      widget.onUserUpdated?.call(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль успешно обновлен'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      // Fallback: update locally if offline
      setState(() {
        _currentUser['name'] = newName;
        _isEditing = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_currentUser));
      widget.onUserUpdated?.call(_currentUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Имя сохранено локально'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('Выход из системы', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Вы действительно хотите выйти из своего аккаунта? Локальные данные сохранятся на этом устройстве.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _currentUser['name'] as String? ?? 'Студент';
    final email = _currentUser['email'] as String? ?? '';
    final role = _currentUser['role'] as String? ?? 'student';
    final isHeadman = role == 'headman';
    final groupTitle = widget.group?['title'] as String?;
    final semester = (widget.group?['semester'] as num?)?.toInt();
    final inviteCode = widget.group?['invite_code'] as String?;
    final userId = _currentUser['id'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профиль пользователя', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Выйти из системы',
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top User Profile Card
                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Avatar with Role badge
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: isHeadman
                                  ? AppColors.plate(AppColors.accent, 0.3)
                                  : AppColors.plate(AppColors.accentCyan, 0.3),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: isHeadman ? AppColors.accent : AppColors.accentCyan,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isHeadman ? AppColors.accent : AppColors.accentCyan,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.surface, width: 2),
                              ),
                              child: Text(
                                isHeadman ? 'Староста' : 'Студент',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isEditing) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Имя и фамилия',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                                onPressed: _saveProfile,
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: AppColors.textSecondary, size: 28),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                    _nameController.text = _currentUser['name'] as String? ?? '';
                                  });
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.accentCyan),
                                tooltip: 'Редактировать имя',
                                onPressed: () => setState(() => _isEditing = true),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Group & Academic Info
                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.school_outlined, color: AppColors.accentCyan, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Академическая группа',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Группа:', groupTitle ?? 'Группа не выбрана'),
                        const Divider(color: AppColors.border, height: 18),
                        if (semester != null) ...[
                          _buildInfoRow('Семестр:', '$semester'),
                          const Divider(color: AppColors.border, height: 18),
                        ],
                        if (inviteCode != null) ...[
                          _buildInfoRow('Код приглашения:', inviteCode, isCode: true),
                          const Divider(color: AppColors.border, height: 18),
                        ],
                        _buildInfoRow('Роль в системе:', isHeadman ? 'Староста (Полный доступ)' : 'Студент'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tasks & Deadlines Statistics (Criteria 8 & 9)
                StreamBuilder<List<Task>>(
                  stream: (widget.db.select(widget.db.tasks)
                        ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
                      .watch(),
                  builder: (context, snapshot) {
                    final tasks = snapshot.data ?? [];
                    final total = tasks.length;
                    final completed = tasks.where((t) => t.status == 'completed').length;
                    final pending = total - completed;
                    final progress = total > 0 ? (completed / total) : 0.0;

                    return Card(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.analytics_outlined, color: AppColors.accent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Статистика успеваемости',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatTile('Всего задач', '$total', AppColors.textPrimary),
                                ),
                                Expanded(
                                  child: _buildStatTile('В процессе', '$pending', AppColors.warning),
                                ),
                                Expanded(
                                  child: _buildStatTile('Выполнено', '$completed', AppColors.success),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: AppColors.elevated,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${(progress * 100).toInt()}% выполнено',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // API Backend Connection Info Card
                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.dns_rounded, size: 18, color: AppColors.accentCyan),
                                SizedBox(width: 8),
                                Text(
                                  'Подключение к API серверу',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.accent),
                              tooltip: 'Сменить адрес API',
                              onPressed: () => ServerConfigDialog.show(
                                context,
                                widget.apiClient,
                                onSaved: () => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 8, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.apiClient.dio.options.baseUrl,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Logout Action Button (Criteria 10)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Выйти из системы',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _confirmLogout,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isCode = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (isCode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: AppColors.accentCyan,
                fontSize: 13,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  Widget _buildStatTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
