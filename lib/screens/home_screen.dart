import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/interface_language.dart';
import '../models/notification_interval.dart';
import '../models/topic.dart';
import '../services/app_controller.dart';
import 'settings_screen.dart';
import 'topic_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final strings = AppStrings(controller.settings.interfaceLanguage!);
        return Scaffold(
          appBar: AppBar(
            title: const Text('UneBil'),
            actions: [
              IconButton(
                tooltip: strings.settings,
                icon: const Icon(Icons.tune),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(controller: controller),
                    ),
                  );
                },
              ),
            ],
          ),
          body: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : _HomeContent(controller: controller),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showTopicDialog(context, controller),
            icon: const Icon(Icons.add),
            label: Text(strings.topic),
          ),
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final topics = controller.topics;
    final settings = controller.settings;
    final strings = AppStrings(settings.interfaceLanguage!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _SettingsSummary(
          language: settings.language.label,
          length: strings.aboutWords(settings.length.targetWords),
          title: strings.homeSlogan,
        ),
        const SizedBox(height: 16),
        if (topics.isEmpty)
          _EmptyTopics(
            strings: strings,
            onAdd: () => _showTopicDialog(context, controller),
          )
        else
          ...topics.map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopicTile(
                topic: topic,
                factCount: controller.factsForTopic(topic.id).length,
                intervalLabel: topic.notificationInterval.label(
                  settings.interfaceLanguage!,
                ),
                strings: strings,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TopicDetailScreen(
                        controller: controller,
                        topicId: topic.id,
                      ),
                    ),
                  );
                },
                onToggle: (enabled) =>
                    controller.toggleTopic(topic.id, enabled),
                onEdit: () =>
                    _showTopicDialog(context, controller, existingTopic: topic),
                onDelete: () => controller.deleteTopic(topic.id),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsSummary extends StatelessWidget {
  const _SettingsSummary({
    required this.language,
    required this.length,
    required this.title,
  });

  final String language;
  final String length;
  final String title;

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.language, label: language),
                _InfoChip(icon: Icons.short_text, label: length),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyTopics extends StatelessWidget {
  const _EmptyTopics({required this.strings, required this.onAdd});

  final AppStrings strings;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              strings.addFirstTopic,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(strings.emptyTopicsBody, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(strings.addTopic),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.factCount,
    required this.intervalLabel,
    required this.strings,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Topic topic;
  final int factCount;
  final String intervalLabel;
  final AppStrings strings;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(topic.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          topic.enabled
              ? '${strings.factsCount(factCount)} · $intervalLabel'
              : '${strings.factsCount(factCount)} · ${strings.notificationsOff}',
        ),
        leading: Switch(value: topic.enabled, onChanged: onToggle),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(strings.editTopicAndInterval),
            ),
            PopupMenuItem(value: 'delete', child: Text(strings.delete)),
          ],
        ),
      ),
    );
  }
}

Future<void> _showTopicDialog(
  BuildContext context,
  AppController controller, {
  Topic? existingTopic,
}) async {
  final value = await showDialog<_TopicDraft>(
    context: context,
    builder: (_) => _TopicDialog(
      initialTitle: existingTopic?.title,
      initialInterval: existingTopic?.notificationInterval,
      language: controller.settings.interfaceLanguage!,
    ),
  );

  if (value == null || value.title.isEmpty) {
    return;
  }
  if (existingTopic == null) {
    await controller.addTopic(value.title, interval: value.interval);
  } else {
    await controller.updateTopic(
      existingTopic.id,
      title: value.title,
      interval: value.interval,
    );
  }
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog({
    this.initialTitle,
    this.initialInterval,
    required this.language,
  });

  final String? initialTitle;
  final NotificationInterval? initialInterval;
  final InterfaceLanguage language;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final TextEditingController _textController;
  late NotificationInterval _interval;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialTitle ?? '');
    _interval = widget.initialInterval ?? NotificationInterval.everyTwoHours;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);
    final isEditing = widget.initialTitle != null;
    final title = isEditing ? strings.editTopicAndInterval : strings.newTopic;
    final action = isEditing ? strings.save : strings.add;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: strings.topic,
              hintText: strings.topicExample,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<NotificationInterval>(
            initialValue: _interval,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: NotificationInterval.selectorLabel(widget.language),
            ),
            items: NotificationInterval.values
                .map(
                  (interval) => DropdownMenuItem<NotificationInterval>(
                    value: interval,
                    child: Text(interval.label(widget.language)),
                  ),
                )
                .toList(),
            onChanged: (interval) {
              if (interval != null) {
                setState(() => _interval = interval);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(action)),
      ],
    );
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop(_TopicDraft(title: _textController.text.trim(), interval: _interval));
  }
}

class _TopicDraft {
  const _TopicDraft({required this.title, required this.interval});

  final String title;
  final NotificationInterval interval;
}
