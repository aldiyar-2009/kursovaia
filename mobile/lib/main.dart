import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/services/connect_link.dart';
import 'package:studyplan/core/services/notification_service.dart';
import 'package:studyplan/core/settings/app_settings.dart';
import 'package:studyplan/core/widgets/connect_link_prompt.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/group/data/group_repository.dart';
import 'package:studyplan/features/splash/presentation/screens/splash_screen.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline local notifications
  await NotificationService().initialize();

  final settings = AppSettings();
  await settings.load();

  // Web invite link `<server>/join/<code>`: keep the code for the join form.
  if (kIsWeb) await GroupRepository.storePendingInviteFromPath(Uri.base.path);

  final db = AppDatabase();
  final apiClient = ApiClient();

  // Opened from the server's QR code: the address is saved after the user
  // confirms it (ConnectLinkPrompt).
  final connectLinks = ConnectLinkService(apiClient: apiClient);
  await connectLinks.start();

  runApp(StudyPlanApp(
    db: db,
    apiClient: apiClient,
    settings: settings,
    connectLinks: connectLinks,
  ));
}

class StudyPlanApp extends StatelessWidget {
  final AppDatabase db;
  final ApiClient apiClient;
  final AppSettings settings;
  final ConnectLinkService? connectLinks;

  const StudyPlanApp({
    super.key,
    required this.db,
    required this.apiClient,
    required this.settings,
    this.connectLinks,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        builder: connectLinks == null
            ? null
            : (context, child) =>
                ConnectLinkPrompt(service: connectLinks!, child: child!),
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
