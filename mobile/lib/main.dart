import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/services/notification_service.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/splash/presentation/screens/splash_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline local notifications
  await NotificationService().initialize();

  final settings = AppSettings();
  await settings.load();

  final db = AppDatabase();
  final apiClient = ApiClient();

  runApp(StudyPlanApp(db: db, apiClient: apiClient, settings: settings));
}

class StudyPlanApp extends StatelessWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;

  const StudyPlanApp({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).common_appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode,
        locale: settings.locale,
        localeListResolutionCallback: (device, _) =>
            resolveLocale(device ?? const []),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: kSupportedLocales,
        home: SplashScreen(
          db: db,
          apiClient: apiClient,
          settings: settings,
        ),
      ),
    );
  }
}
