import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/sync/sync_bloc.dart';
import 'package:studyplan/core/theme/theme_ext.dart';
import 'package:studyplan/features/lms/data/lms_importer.dart';
import 'package:studyplan/features/lms/data/moodle_ajax_parser.dart';

import 'lms_webview.dart';
import 'widgets/lms_import_result_view.dart';

export 'lms_webview.dart' show isLmsImportSupported;
export 'widgets/lms_import_result_view.dart' show LmsImportResultView;

/// Opens the LMS import and returns its summary, or null when the user
/// left before anything was saved. After a successful import a sync is
/// requested through the caller's [SyncBloc], if one is above [context].
Future<LmsImportSummary?> openLmsImport(
  BuildContext context, {
  required AppDatabase db,
  required String userId,
}) async {
  SyncBloc? sync;
  try {
    sync = context.read<SyncBloc>();
  } catch (_) {
    sync = null;
  }
  final summary = await Navigator.of(context).push<LmsImportSummary>(
    MaterialPageRoute(
      builder: (_) => LmsImportScreen(db: db, userId: userId),
    ),
  );
  if (summary != null && sync != null && !sync.isClosed) {
    sync.add(SyncTriggered());
  }
  return summary;
}

enum _Step { intro, login, loading, result, error }

class LmsImportScreen extends StatefulWidget {
  const LmsImportScreen({
    super.key,
    required this.db,
    required this.userId,
  });

  final AppDatabase db;
  final String userId;

  static const scriptTimeout = Duration(seconds: 60);

  @override
  State<LmsImportScreen> createState() => _LmsImportScreenState();
}

class _LmsImportScreenState extends State<LmsImportScreen> {
  _Step _step = _Step.intro;
  bool _webViewStarted = false;
  LmsWebViewController? _controller;
  Uri? _currentUrl;
  int _progress = 0;
  bool _running = false;
  bool _timedOut = false;
  LmsImportSummary? _summary;

  void _startLogin() {
    setState(() {
      _step = _Step.login;
      _webViewStarted = true;
    });
  }

  Future<void> _onLoadStop(Uri? url) async {
    if (_step != _Step.login || _running || !isLmsAppPage(url)) return;
    final c = _controller;
    if (c == null) return;
    if (await c.hasSesskey() && mounted && _step == _Step.login) {
      await _runImport();
    }
  }

  Future<void> _runImport() async {
    final c = _controller;
    if (c == null || _running) return;
    setState(() {
      _running = true;
      _step = _Step.loading;
    });
    try {
      final window = lmsImportWindow(DateTime.now());
      final raw = await c
          .runImport(sinceSec: window.sinceSec, untilSec: window.untilSec)
          .timeout(LmsImportScreen.scriptTimeout);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('not an object');
      final result = buildImportResult(Map<String, dynamic>.from(decoded));
      final summary = await applyImport(
        widget.db,
        widget.userId,
        result,
        now: DateTime.now(),
        prefs: await SharedPreferences.getInstance(),
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _step = _Step.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timedOut = e is TimeoutException;
        _step = _Step.error;
      });
    } finally {
      _running = false;
    }
  }

  void _close() => Navigator.of(context).pop(_summary);

  @override
  Widget build(BuildContext context) {
    return PopScope<LmsImportSummary>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _step == _Step.loading) return;
        _close();
      },
      child: Scaffold(
        appBar: _step == _Step.login ? _browserBar(context) : _plainBar(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_webViewStarted)
              LmsWebView(
                initialUrl: kLmsLoginUrl,
                onCreated: (c) => _controller = c,
                onLoadStop: _onLoadStop,
                onUrlChanged: (url) {
                  if (mounted && url != null) setState(() => _currentUrl = url);
                },
                onProgress: (p) {
                  if (mounted) setState(() => _progress = p);
                },
              ),
            if (_step != _Step.login)
              ColoredBox(
                color: context.palette.background,
                child: _overlay(context),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _plainBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: _step == _Step.loading
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.lms_close,
              onPressed: _close,
            ),
      title: Text(context.l10n.lms_importTitle),
    );
  }

  PreferredSizeWidget _browserBar(BuildContext context) {
    final p = context.palette;
    final url = _currentUrl ?? kLmsLoginUrl;
    final secure = url.scheme == 'https';
    final loading = _progress < 100;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 48,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.lms_cancelLogin,
        onPressed: _close,
      ),
      title: Row(
        children: [
          Icon(
            secure ? Icons.lock_outline : Icons.info_outline,
            size: 16,
            color: p.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              url.host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium!.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
      shape: Border(bottom: BorderSide(color: p.border)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: SizedBox(
          height: 2,
          child: loading
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  minHeight: 2,
                  color: p.accent,
                  backgroundColor: Colors.transparent,
                )
              : null,
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final l = context.l10n;
    switch (_step) {
      case _Step.intro:
      case _Step.login:
        return LmsImportIntroView(onSignIn: _startLogin);
      case _Step.loading:
        return const _LoadingView();
      case _Step.result:
        return LmsImportResultView(
          summary: _summary!,
          onRetry: _runImport,
          onDone: _close,
        );
      case _Step.error:
        return _MessageView(
          title: l.lms_errorTitle,
          message: _timedOut ? l.lms_errorTimeout : l.lms_errorGeneric,
          primaryLabel: l.lms_retry,
          onPrimary: _runImport,
          secondaryLabel: _summary != null ? l.lms_done : l.lms_close,
          onSecondary: _close,
        );
    }
  }
}

/// First step: what is imported and where the password goes.
class LmsImportIntroView extends StatelessWidget {
  const LmsImportIntroView({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final t = context.text;
    final kinds = <(String, String)>[
      (l.lms_kindGrades, l.lms_kindGradesHint),
      (l.lms_kindDeadlines, l.lms_kindDeadlinesHint),
      (l.lms_kindSchedule, l.lms_kindScheduleHint),
      (l.lms_kindMaterials, l.lms_kindMaterialsHint),
      (l.lms_kindProfile, l.lms_kindProfileHint),
    ];

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    Text(l.lms_introHeading, style: t.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      l.lms_introLead,
                      style: t.bodyMedium!.copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    for (final (title, hint) in kinds)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: title,
                                style: t.bodyMedium!
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text: '  $hint',
                                style: t.bodyMedium!
                                    .copyWith(color: p.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 20, color: p.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l.lms_privacy, style: t.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.lms_introNote,
                      style: t.bodySmall!.copyWith(color: p.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 528),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSignIn,
                  child: Text(l.lms_signIn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
            ),
            const SizedBox(height: 20),
            Text(
              l.lms_loadingTitle,
              textAlign: TextAlign.center,
              style: context.text.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              l.lms_loadingHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall!.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  textAlign: TextAlign.center, style: context.text.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium!
                    .copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
