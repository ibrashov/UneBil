import 'package:flutter/material.dart';

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
    required this.generating,
    required this.onGenerate,
  });

  final Topic topic;
  final String language;
  final String length;
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
              ],
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
