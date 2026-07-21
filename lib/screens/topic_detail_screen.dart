import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_language.dart';
import '../models/app_time_zone.dart';
import '../models/notification_interval.dart';
import '../models/topic.dart';
import '../services/app_controller.dart';

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
        final topic = controller.topics
            .where((candidate) => candidate.id == topicId)
            .firstOrNull;
        if (topic == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Тема')),
            body: const Center(child: Text('Тема удалена')),
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

        return Scaffold(
          appBar: AppBar(title: Text(topic.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TopicHeader(
                topic: topic,
                language: controller.settings.language.label,
                length:
                    '${controller.settings.length.label} · ${controller.settings.length.targetWords} слов',
                interval: topic.notificationInterval.label(
                  controller.settings.language,
                ),
                selectedInterval: topic.notificationInterval,
                intervalLanguage: controller.settings.language,
                onIntervalChanged: (interval) {
                  controller.updateTopicInterval(topic.id, interval);
                },
                generating: generating,
                onGenerate: () async {
                  final addedCount = await controller.generateFactsForTopic(
                    topic.id,
                  );
                  if (!context.mounted) {
                    return;
                  }

                  final message =
                      controller.generationErrorForTopic(topic.id) ??
                      (addedCount > 0
                          ? 'Готово: факт добавлен.'
                          : 'Backend вернул пустой ответ.');
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(message)));
                },
              ),
              if (generationError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: generationError),
              ],
              const SizedBox(height: 16),
              if (facts.isEmpty)
                const _NoFactsYet()
              else
                ...facts.map(
                  (fact) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fact.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(fact.body),
                            const SizedBox(height: 12),
                            Text(
                              '${fact.language.label} · ${fact.length.label}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            _NotificationSchedule(
                              enabled: topic.enabled,
                              scheduledAt: nextNotificationByFact[fact.id],
                              timeZone: controller.settings.timeZone,
                            ),
                          ],
                        ),
                      ),
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

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({
    required this.topic,
    required this.language,
    required this.length,
    required this.interval,
    required this.selectedInterval,
    required this.intervalLanguage,
    required this.onIntervalChanged,
    required this.generating,
    required this.onGenerate,
  });

  final Topic topic;
  final String language;
  final String length;
  final String interval;
  final NotificationInterval selectedInterval;
  final AppLanguage intervalLanguage;
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
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Как часто показывать уведомления',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
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
                                notificationInterval.label(intervalLanguage),
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
                  generating ? 'Генерируем...' : 'Сгенерировать факт',
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
  });

  final bool enabled;
  final DateTime? scheduledAt;
  final AppTimeZone timeZone;
  static bool _timeZonesInitialized = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = !enabled
        ? 'Уведомления для темы выключены'
        : scheduledAt == null
        ? 'Пока не входит в ближайшее расписание'
        : 'Следующее уведомление: ${_formatDateTime(scheduledAt!, timeZone)} '
              '(${timeZone.label})';

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
    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }
    final zonedValue = tz.TZDateTime.from(
      value,
      tz.getLocation(timeZone.locationName),
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
  const _NoFactsYet();

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
              'Пока нет фактов',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Нажми кнопку генерации, чтобы подготовить факты для уведомлений.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
