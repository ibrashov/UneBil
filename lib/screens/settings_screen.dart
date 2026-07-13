import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../models/app_time_zone.dart';
import '../models/notification_length.dart';
import '../services/app_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Настройки')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SettingsCard(
                title: 'Язык фактов',
                child: SegmentedButton<AppLanguage>(
                  segments: AppLanguage.values
                      .map(
                        (language) => ButtonSegment<AppLanguage>(
                          value: language,
                          label: Text(language.label),
                        ),
                      )
                      .toList(),
                  selected: <AppLanguage>{settings.language},
                  onSelectionChanged: (selection) {
                    controller.updateLanguage(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: 'Time zone',
                child: DropdownButtonFormField<AppTimeZone>(
                  initialValue: settings.timeZone,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                  items: AppTimeZone.values
                      .map(
                        (timeZone) => DropdownMenuItem<AppTimeZone>(
                          value: timeZone,
                          child: Text(timeZone.label),
                        ),
                      )
                      .toList(),
                  onChanged: (timeZone) {
                    if (timeZone != null) {
                      controller.updateTimeZone(timeZone);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: 'Длина уведомления',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<NotificationLength>(
                      segments: NotificationLength.values
                          .map(
                            (length) => ButtonSegment<NotificationLength>(
                              value: length,
                              label: Text(length.label),
                            ),
                          )
                          .toList(),
                      selected: <NotificationLength>{settings.length},
                      onSelectionChanged: (selection) {
                        controller.updateLength(selection.first);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text('Около ${settings.length.targetWords} слов'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: 'Проверка расписания',
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _sendTestNotification(context, controller),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Запланировать факт через 15 секунд'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> _sendTestNotification(
  BuildContext context,
  AppController controller,
) async {
  final delivered = await controller.showTestNotification();
  if (!context.mounted) {
    return;
  }

  final message = delivered
      ? 'Факт запланирован через 15 секунд. Закрой приложение и подожди.'
      : controller.lastError ?? 'Не удалось показать тестовое уведомление.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
