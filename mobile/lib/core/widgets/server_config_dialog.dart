import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/theme/app_colors.dart';

class ServerConfigDialog extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onSaved;

  const ServerConfigDialog({
    super.key,
    required this.apiClient,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, ApiClient apiClient, {VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => ServerConfigDialog(apiClient: apiClient, onSaved: onSaved),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  String? _testResult;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.apiClient.dio.options.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = 'Проверка соединения...';
    });

    try {
      final testDio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final res = await testDio.get('/health');
      if (res.statusCode == 200) {
        setState(() {
          _testResult = '✅ Сервер доступен (200 OK)';
          _isTesting = false;
        });
      } else {
        setState(() {
          _testResult = '❌ Ответ сервера: ${res.statusCode}';
          _isTesting = false;
        });
      }
    } catch (_) {
      setState(() {
        _testResult = '❌ Не удалось подключиться к $url';
        _isTesting = false;
      });
    }
  }

  Future<void> _save() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty) {
      widget.apiClient.updateBaseUrl(newUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', newUrl);
      widget.onSaved?.call();
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Адрес API сохранен: $newUrl'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: AppColors.accentCyan, size: 24),
          SizedBox(width: 10),
          Text(
            'Настройка API сервера',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Укажите адрес бэкенда для связи приложения с базой данных:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlController,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://192.168.8.72:3000/api',
                prefixIcon: Icon(Icons.link_rounded, size: 20, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Быстрый выбор адреса:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  backgroundColor: AppColors.elevated,
                  label: const Text('Wi-Fi сеть (192.168.8.72)'),
                  labelStyle: const TextStyle(fontSize: 11, color: AppColors.accentCyan),
                  onPressed: () => setState(() => _urlController.text = 'http://192.168.8.72:3000/api'),
                ),
                ActionChip(
                  backgroundColor: AppColors.elevated,
                  label: const Text('Localhost (127.0.0.1)'),
                  labelStyle: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                  onPressed: () => setState(() => _urlController.text = 'http://127.0.0.1:3000/api'),
                ),
                ActionChip(
                  backgroundColor: AppColors.elevated,
                  label: const Text('Android Эмулятор (10.0.2.2)'),
                  labelStyle: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                  onPressed: () => setState(() => _urlController.text = 'http://10.0.2.2:3000/api'),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _testResult!.startsWith('✅')
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _testResult!.startsWith('✅') ? AppColors.success : AppColors.danger,
                    width: 1,
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _testResult!.startsWith('✅') ? AppColors.accentCyan : AppColors.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton.icon(
          onPressed: _isTesting ? null : _testConnection,
          icon: _isTesting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                )
              : const Icon(Icons.wifi_tethering_rounded, size: 16),
          label: const Text('Проверить связь'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
