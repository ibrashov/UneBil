import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/ai_client.dart';
import 'services/app_controller.dart';
import 'services/notification_scheduler.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final controller = AppController(
    StorageService(prefs),
    AiClient(),
    NotificationScheduler(),
  );
  WidgetsBinding.instance.addObserver(controller);
  await controller.load();

  runApp(UneBilApp(controller: controller));
}

class UneBilApp extends StatelessWidget {
  const UneBilApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UneBil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
