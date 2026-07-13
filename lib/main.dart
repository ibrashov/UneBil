import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/ai_client.dart';
import 'services/app_controller.dart';
import 'services/notification_scheduler.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/fact_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final scheduler = NotificationScheduler();
  final controller = AppController(
    StorageService(prefs),
    AiClient(),
    scheduler,
  );
  WidgetsBinding.instance.addObserver(controller);
  await controller.load();

  final launchNotification = await scheduler.launchNotification;
  runApp(
    UneBilApp(
      controller: controller,
      scheduler: scheduler,
      launchNotification: launchNotification,
    ),
  );
}

class UneBilApp extends StatefulWidget {
  const UneBilApp({
    super.key,
    required this.controller,
    this.scheduler,
    this.launchNotification,
  });

  final AppController controller;
  final NotificationScheduler? scheduler;
  final NotificationTarget? launchNotification;

  @override
  State<UneBilApp> createState() => _UneBilAppState();
}

class _UneBilAppState extends State<UneBilApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<NotificationTarget>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = widget.scheduler?.notificationTaps.listen(
      _openNotification,
    );
    final launchNotification = widget.launchNotification;
    if (launchNotification != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNotification(launchNotification),
      );
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _openNotification(NotificationTarget target) {
    final fact = widget.controller.facts
        .where((candidate) => candidate.id == target.factId)
        .firstOrNull;
    final navigator = _navigatorKey.currentState;
    if (fact == null || navigator == null) {
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => FactDetailScreen(fact: fact)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      home: HomeScreen(controller: widget.controller),
    );
  }
}
