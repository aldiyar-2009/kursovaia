import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/core/widgets/ui/app_text_field.dart';

/// Dialog for changing the API base URL at runtime.
class ServerConfigDialog extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onSaved;

  const ServerConfigDialog({
    super.key,
    required this.apiClient,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context,
    ApiClient apiClient, {
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) =>
          ServerConfigDialog(apiClient: apiClient, onSaved: onSaved),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

enum _TestState { idle, testing, ok, failed }

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  _TestState _testState = _TestState.idle;
  String? _testMessage;
  String? _urlError;

  static const _presets = <(String, String)>[
    ('local', 'http://127.0.0.1:3000/api'),
    ('emulator', 'http://10.0.2.2:3000/api'),
    ('lan', 'http://192.168.8.72:3000/api'),
  ];

  @override
  void initState() {
    super.initState();
    _urlController =
        TextEditingController(text: widget.apiClient.dio.options.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool _isValid(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _testConnection() async {
    final l10n = context.l10n;
    final url = _urlController.text.trim();
    if (!_isValid(url)) {
      setState(() => _urlError = l10n.profile_serverInvalid);
      return;
    }
    setState(() {
      _urlError = null;
      _testState = _TestState.testing;
      _testMessage = l10n.profile_serverTesting;
    });

    try {
      final testDio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final res = await testDio.get('/health');
      if (!mounted) return;
      setState(() {
        if (res.statusCode == 200) {
          _testState = _TestState.ok;
          _testMessage = l10n.profile_serverOk;
        } else {
          _testState = _TestState.failed;
          _testMessage = l10n.profile_serverBadStatus(res.statusCode ?? 0);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testState = _TestState.failed;
        _testMessage = l10n.profile_serverUnreachable;
      });
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final newUrl = _urlController.text.trim();
    if (!_isValid(newUrl)) {
      setState(() => _urlError = l10n.profile_serverInvalid);
      return;
    }
    widget.apiClient.updateBaseUrl(newUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', newUrl);
    widget.onSaved?.call();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(l10n.profile_serverSaved)));
  }

  String _presetLabel(String id) {
    final l10n = context.l10n;
    return switch (id) {
      'local' => l10n.profile_serverPresetLocal,
      'emulator' => l10n.profile_serverPresetEmulator,
      _ => l10n.profile_serverPresetLan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final statusColor = switch (_testState) {
      _TestState.ok => palette.success,
      _TestState.failed => palette.danger,
      _ => palette.textSecondary,
    };

    return AlertDialog(
      title: Text(l10n.profile_serverTitle),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.profile_serverMessage),
              const SizedBox(height: 16),
              AppTextField(
                controller: _urlController,
                label: l10n.profile_serverUrlLabel,
                hint: 'http://127.0.0.1:3000/api',
                keyboardType: TextInputType.url,
                errorText: _urlError,
                onChanged: (_) {
                  if (_urlError != null || _testState != _TestState.idle) {
                    setState(() {
                      _urlError = null;
                      _testState = _TestState.idle;
                      _testMessage = null;
                    });
                  }
                },
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.profile_serverPresets,
                style: context.text.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (id, url) in _presets)
                    ActionChip(
                      label: Text(_presetLabel(id)),
                      tooltip: url,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        _urlController.text = url;
                        _urlError = null;
                        _testState = _TestState.idle;
                        _testMessage = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _testState == _TestState.testing
                        ? null
                        : _testConnection,
                    child: Text(l10n.profile_serverTest),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _testMessage ?? '',
                      style:
                          context.text.bodySmall!.copyWith(color: statusColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.common_save)),
      ],
    );
  }
}
