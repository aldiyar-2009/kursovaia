import 'package:flutter/material.dart';
import 'package:studyplan/core/database/app_database.dart';
import 'package:studyplan/core/network/api_client.dart';
import 'package:studyplan/core/services/notification_service.dart';
import 'package:studyplan/core/theme/app_theme.dart';
import 'package:studyplan/features/splash/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline local notifications
  await NotificationService().initialize();

  final db = AppDatabase();
  final apiClient = ApiClient();

  runApp(StudyPlanApp(db: db, apiClient: apiClient));
}

class StudyPlanApp extends StatelessWidget {
  final AppDatabase db;
  final ApiClient apiClient;

  const StudyPlanApp({super.key, required this.db, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyPlan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: SplashScreen(
        db: db,
        apiClient: apiClient,
      ),
    );
  }
}
