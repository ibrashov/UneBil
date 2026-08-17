import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../localization/app_strings.dart';
import '../models/app_time_zone.dart';
import '../models/learning_fact.dart';
import '../models/notification_interval.dart';
import '../models/topic.dart';
import '../services/app_controller.dart';
import '../services/fact_generator.dart';
import '../widgets/unread_indicator.dart';
import 'fact_detail_screen.dart';

class TopicDetailScreen extends StatelessWidget {
  const TopicDetailScreen({
    super.key,
    required this.controller,
    required this.topicId,
  });

  final AppController controller;
  final String topicId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final strings = AppStrings(controller.settings.interfaceLanguage!);
        final topic = controller.topics
            .where((candidate) => candidate.id == topicId)
            .firstOrNull;
        if (topic == null) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.topic)),
            body: Center(child: Text(strings.topicDeleted)),
          );
        }

        final facts = controller.factsForTopic(topic.id);
        final notificationPlan = controller.notificationPlanForTopic(topic.id);
        final nextNotificationByFact = <String, DateTime>{};
        for (final notification in notificationPlan) {
          nextNotificationByFact.putIfAbsent(
            notification.factId,
            () => notification.scheduledAt,
          );
        }
        final generating = controller.isGeneratingTopic(topic.id);
        final generationError = controller.generationErrorForTopic(topic.id);
        final unreadCount = controller.unreadCountForTopic(topic.id);

        return Scaffold(
          appBar: AppBar(title: Text(topic.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TopicHeader(
                topic: topic,
                language: controller.settings.language.label,
                length: strings.aboutWords(
                  controller.settings.length.targetWords,
                ),
                interval: topic.notificationInterval.label(
                  controller.settings.interfaceLanguage!,
                ),
                selectedInterval: topic.notificationInterval,
                strings: strings,
                onEnabledChanged: (enabled) {
                  controller.toggleTopic(topic.id, enabled);
                },
                onIntervalChanged: (interval) {
                  controller.updateTopicInterval(topic.id, interval);
                },
                generating: generating,
                onGenerate: () async {
                  final addedCount = await controller.generateFactsForTopic(
                    topic.id,
                    count: factGenerationBatchSize,
                  );
                  if (!context.mounted) {
                    return;
                  }

                  final error = controller.generationErrorForTopic(topic.id);
                  final localizedMessage = error != null
                      ? strings.localizeGenerationError(error)
                      : addedCount > 0
                      ? strings.factsAdded(addedCount)
                      : strings.emptyBackendResponse;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(localizedMessage)));
                },
              ),
              if (unreadCount > 0) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => controller.markAllFactsRead(topic.id),
                    icon: const Icon(Icons.done_all),
                    label: Text(strings.markAllAsRead),
                  ),
                ),
              ],
              if (generationError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(
                  message: strings.localizeGenerationError(generationError),
                ),
              ],
              const SizedBox(height: 16),
              if (facts.isEmpty)
                _NoFactsYet(strings: strings)
              else
                ...facts.map(
                  (fact) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FactCard(
                      fact: fact,
                      strings: strings,
                      notificationEnabled: topic.enabled,
                      scheduledAt: nextNotificationByFact[fact.id],
                      timeZone: controller.settings.timeZone,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FactDetailScreen(
                            controller: controller,
                            factId: fact.id,
                          ),
                        ),
                      ),
                      onReadToggle: () => fact.isRead
                          ? controller.markFactUnread(fact.id)
                          : controller.markFactRead(fact.id),
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

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.fact,
    required this.strings,
    required this.notificationEnabled,
    required this.scheduledAt,
    required this.timeZone,
    required this.onTap,
    required this.onReadToggle,
  });

  final LearningFact fact;
  final AppStrings strings;
  final bool notificationEnabled;
  final DateTime? scheduledAt;
  final AppTimeZone timeZone;
  final VoidCallback onTap;
  final VoidCallback onReadToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: fact.isRead
                    ? const SizedBox(width: 9)
                    : UnreadIndicator(semanticLabel: strings.unreadCount(1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fact.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: fact.isRead
                            ? FontWeight.w600
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fact.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: fact.isRead
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${fact.language.label} · ${strings.lengthLabel(fact.length)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _NotificationSchedule(
                      enabled: notificationEnabled,
                      scheduledAt: scheduledAt,
                      timeZone: timeZone,
                      strings: strings,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (_) => onReadToggle(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'read-state',
                    child: Text(
                      fact.isRead ? strings.markAsUnread : strings.markAsRead,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({
    required this.topic,
    required this.language,
    required this.length,
    required this.interval,
    required this.selectedInterval,
    required this.strings,
    required this.onEnabledChanged,
    required this.onIntervalChanged,
    required this.generating,
    required this.onGenerate,
  });

  final Topic topic;
  final String language;
  final String length;
  final String interval;
  final NotificationInterval selectedInterval;
  final AppStrings strings;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<NotificationInterval> onIntervalChanged;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.language, size: 18),
                  label: Text(language),
                ),
                Chip(
                  avatar: const Icon(Icons.short_text, size: 18),
                  label: Text(length),
                ),
                Chip(
                  avatar: const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                  ),
                  label: Text(interval),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.topicNotifications),
              subtitle: Text(
                topic.enabled
                    ? strings.topicNotificationsOn
                    : strings.topicNotificationsOff,
              ),
              value: topic.enabled,
              onChanged: onEnabledChanged,
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                labelText: strings.notificationFrequency,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.schedule),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<NotificationInterval>(
                  value: selectedInterval,
                  isExpanded: true,
                  items: NotificationInterval.values
                      .map(
                        (notificationInterval) =>
                            DropdownMenuItem<NotificationInterval>(
                              value: notificationInterval,
                              child: Text(
                                strings.intervalLabel(notificationInterval),
                              ),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (notificationInterval) {
                    if (notificationInterval != null) {
                      onIntervalChanged(notificationInterval);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: generating ? null : onGenerate,
                icon: generating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  generating ? strings.generating : strings.generateFact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSchedule extends StatelessWidget {
  const _NotificationSchedule({
    required this.enabled,
    required this.scheduledAt,
    required this.timeZone,
    required this.strings,
  });

  final bool enabled;
  final DateTime? scheduledAt;
  final AppTimeZone timeZone;
  final AppStrings strings;
  static bool _timeZonesInitialized = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = !enabled
        ? strings.topicNotificationsOff
        : scheduledAt == null
        ? strings.notInUpcomingSchedule
        : strings.nextNotification(
            _formatDateTime(scheduledAt!, timeZone),
            strings.timeZoneLabel(timeZone),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          enabled && scheduledAt != null
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          size: 17,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }

  static String _formatDateTime(DateTime value, AppTimeZone timeZone) {
    if (timeZone == AppTimeZone.device) {
      final localValue = value.toLocal();
      String twoDigits(int number) => number.toString().padLeft(2, '0');
      return '${twoDigits(localValue.day)}.${twoDigits(localValue.month)}.'
          '${localValue.year}, '
          '${twoDigits(localValue.hour)}:${twoDigits(localValue.minute)}';
    }
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    final zonedValue = tz.TZDateTime.from(
      value,
      tz.getLocation(timeZone.locationName!),
    );
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(zonedValue.day)}.${twoDigits(zonedValue.month)}.'
        '${zonedValue.year}, '
        '${twoDigits(zonedValue.hour)}:${twoDigits(zonedValue.minute)}';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFactsYet extends StatelessWidget {
  const _NoFactsYet({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              strings.noFactsYet,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(strings.noFactsBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
