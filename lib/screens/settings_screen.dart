import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/app_language.dart';
import '../models/app_time_zone.dart';
import '../models/interface_language.dart';
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
        final strings = AppStrings(settings.interfaceLanguage!);
        return Scaffold(
          appBar: AppBar(title: Text(strings.settings)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SettingsCard(
                title: strings.interfaceLanguage,
                child: SegmentedButton<InterfaceLanguage>(
                  segments: InterfaceLanguage.values
                      .map(
                        (language) => ButtonSegment<InterfaceLanguage>(
                          value: language,
                          label: Text(language.label),
                        ),
                      )
                      .toList(),
                  selected: <InterfaceLanguage>{settings.interfaceLanguage!},
                  onSelectionChanged: (selection) {
                    controller.updateInterfaceLanguage(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: strings.factLanguage,
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
                    controller.updateFactLanguage(selection.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  strings.factLanguageHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: strings.timeZone,
                child: DropdownButtonFormField<AppTimeZone>(
                  initialValue: settings.timeZone,
                  decoration: InputDecoration(
                    labelText: strings.country,
                    border: const OutlineInputBorder(),
                  ),
                  items: AppTimeZone.values
                      .map(
                        (timeZone) => DropdownMenuItem<AppTimeZone>(
                          value: timeZone,
                          child: Text(strings.timeZoneLabel(timeZone)),
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
                title: strings.notificationLength,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<NotificationLength>(
                      segments: NotificationLength.values
                          .map(
                            (length) => ButtonSegment<NotificationLength>(
                              value: length,
                              label: Text(strings.lengthLabel(length)),
                            ),
                          )
                          .toList(),
                      selected: <NotificationLength>{settings.length},
                      onSelectionChanged: (selection) {
                        controller.updateLength(selection.first);
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(strings.aboutWords(settings.length.targetWords)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: strings.notificationTimes,
                child: Column(
                  children: [
                    if (settings.notificationTimes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(strings.noNotificationTimes),
                        ),
                      )
                    else
                      ...settings.notificationTimes.map(
                        (time) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule),
                          title: Text(time.label),
                          trailing: IconButton(
                            tooltip: strings.deleteTime,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              controller.removeNotificationTime(time);
                            },
                          ),
                        ),
                      ),
                    if (settings.notificationTimes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(strings.customTimesHint),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _pickTime(context, controller, strings),
                        icon: const Icon(Icons.add_alarm),
                        label: Text(strings.addTime),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: strings.scheduleTest,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        _sendTestNotification(context, controller, strings),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(strings.scheduleFactIn15Seconds),
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

@visibleForTesting
TimeOfDay addHoursToTimeOfDay(TimeOfDay time, int hours) {
  const minutesInDay = 24 * 60;
  final totalMinutes =
      (time.hour * 60 + time.minute + hours * 60) % minutesInDay;
  return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
}

Future<void> _pickTime(
  BuildContext context,
  AppController controller,
  AppStrings strings,
) async {
  final now = TimeOfDay.now();
  final interval = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.afterHowManyHours,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(strings.chooseNotificationDelay),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final hours in const <int>[1, 2, 3]) ...[
                  if (hours > 1) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, hours),
                      child: Text(strings.hoursShort(hours)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (interval == null || !context.mounted) {
    return;
  }

  final picked = await showTimePicker(
    context: context,
    initialTime: addHoursToTimeOfDay(now, interval),
    helpText: strings.chooseTime,
    cancelText: strings.cancel,
    confirmText: strings.done,
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
  AppStrings strings,
) async {
  final delivered = await controller.showTestNotification();
  if (!context.mounted) {
    return;
  }

  final message = delivered
      ? strings.testScheduled
      : controller.lastError ?? strings.testFailed;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
