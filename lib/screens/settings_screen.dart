import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/app_language.dart';
import '../models/app_theme_mode.dart';
import '../models/app_time_zone.dart';
import '../models/interface_language.dart';
import '../models/notification_length.dart';
import '../models/notification_time.dart';
import '../services/app_controller.dart';
import '../widgets/responsive_segmented_control.dart';

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
                child: ResponsiveSegmentedControl<InterfaceLanguage>(
                  segments: InterfaceLanguage.values
                      .map(
                        (language) => ResponsiveSegment<InterfaceLanguage>(
                          value: language,
                          label: language.label,
                        ),
                      )
                      .toList(),
                  selected: settings.interfaceLanguage!,
                  onSelectionChanged: controller.updateInterfaceLanguage,
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: strings.factLanguage,
                child: ResponsiveSegmentedControl<AppLanguage>(
                  segments: AppLanguage.values
                      .map(
                        (language) => ResponsiveSegment<AppLanguage>(
                          value: language,
                          label: language.label,
                        ),
                      )
                      .toList(),
                  selected: settings.language,
                  onSelectionChanged: controller.updateFactLanguage,
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
                title: strings.appearance,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveSegmentedControl<AppThemeMode>(
                      segments: AppThemeMode.values
                          .map(
                            (mode) => ResponsiveSegment<AppThemeMode>(
                              value: mode,
                              label: strings.themeModeLabel(mode),
                            ),
                          )
                          .toList(),
                      selected: settings.themeMode,
                      onSelectionChanged: controller.updateThemeMode,
                    ),
                    if (settings.themeMode == AppThemeMode.system) ...[
                      const SizedBox(height: 10),
                      Text(
                        strings.systemThemeDescription(
                          MediaQuery.platformBrightnessOf(context) ==
                              Brightness.dark,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: strings.timeZone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<AppTimeZone>(
                      initialValue: settings.timeZone,
                      isExpanded: true,
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
                    const SizedBox(height: 10),
                    Text(
                      strings.quietHoursHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                title: strings.notificationLength,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveSegmentedControl<NotificationLength>(
                      segments: NotificationLength.values
                          .map(
                            (length) => ResponsiveSegment<NotificationLength>(
                              value: length,
                              label: strings.lengthLabel(length),
                            ),
                          )
                          .toList(),
                      selected: settings.length,
                      onSelectionChanged: controller.updateLength,
                    ),
                    const SizedBox(height: 10),
                    Text(strings.aboutWords(settings.length.targetWords)),
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

// Kept for the existing custom-time flow, which is currently not shown.
// ignore: unused_element
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
