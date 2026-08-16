import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'models/interface_language.dart';
import 'services/ai_client.dart';
import 'services/app_controller.dart';
import 'services/notification_scheduler.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/fact_detail_screen.dart';
import 'screens/language_selection_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final scheduler = NotificationScheduler();
  final controller = AppController(
    StorageService(prefs),
    AiClient(),
    scheduler,
  );
  await controller.load();

  final launchNotification = controller.settings.interfaceLanguage == null
      ? null
      : await scheduler.launchNotification;
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
    if (widget.controller.settings.interfaceLanguage == null) {
      return;
    }
    final fact = widget.controller.facts
        .where((candidate) => candidate.id == target.factId)
        .firstOrNull;
    final navigator = _navigatorKey.currentState;
    if (fact == null || navigator == null) {
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FactDetailScreen(controller: widget.controller, factId: fact.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final interfaceLanguage = widget.controller.settings.interfaceLanguage;
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'UneBil',
          debugShowCheckedModeBanner: false,
          locale: interfaceLanguage == null
              ? null
              : Locale(interfaceLanguage.code),
          supportedLocales: InterfaceLanguage.values
              .map((language) => Locale(language.code))
              .toList(growable: false),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: widget.controller.settings.themeMode.materialThemeMode,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.systemUiOverlayStyle(Theme.of(context).brightness),
            child: child ?? const SizedBox.shrink(),
          ),
          home: interfaceLanguage == null
              ? LanguageSelectionScreen(controller: widget.controller)
              : HomeScreen(controller: widget.controller),
        );
      },
    );
  }
}
