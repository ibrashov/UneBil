import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../models/notification_length.dart';
import '../models/notification_time.dart';
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
                title: 'Время уведомлений',
                child: Column(
                  children: [
                    if (settings.notificationTimes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Уведомления не запланированы'),
                        ),
                      )
                    else
                      ...settings.notificationTimes.map(
                        (time) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule),
                          title: Text(time.label),
                          trailing: IconButton(
                            tooltip: 'Удалить время',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              controller.removeNotificationTime(time);
                            },
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(context, controller),
                        icon: const Icon(Icons.add_alarm),
                        label: const Text('Добавить время'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: 'Проверка уведомлений',
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _sendTestNotification(context, controller),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Показать тестовое уведомление'),
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

Future<void> _pickTime(BuildContext context, AppController controller) async {
  final now = TimeOfDay.now();
  final picked = await showTimePicker(
    context: context,
    initialTime: now,
    helpText: 'Выбери время',
    cancelText: 'Отмена',
    confirmText: 'Готово',
  );
  if (picked == null) {
    return;
  }

  await controller.addNotificationTime(
    NotificationTime(hour: picked.hour, minute: picked.minute),
  );
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
      ? 'Тестовое уведомление отправлено. Если его не видно, разреши уведомления для UneBil.'
      : controller.lastError ?? 'Не удалось показать тестовое уведомление.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
