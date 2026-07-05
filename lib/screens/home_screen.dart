import 'package:flutter/material.dart';

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
        return Scaffold(
          appBar: AppBar(
            title: const Text('UneBil'),
            actions: [
              IconButton(
                tooltip: 'Настройки',
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
            label: const Text('Тема'),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _SettingsSummary(
          language: settings.language.label,
          length: '${settings.length.label} · ${settings.length.targetWords} слов',
          times: settings.notificationTimes.map((time) => time.label).join(', '),
        ),
        const SizedBox(height: 16),
        if (topics.isEmpty)
          _EmptyTopics(onAdd: () => _showTopicDialog(context, controller))
        else
          ...topics.map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopicTile(
                topic: topic,
                factCount: controller.factsForTopic(topic.id).length,
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
                onToggle: (enabled) => controller.toggleTopic(topic.id, enabled),
                onEdit: () => _showTopicDialog(
                  context,
                  controller,
                  existingTopic: topic,
                ),
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
    required this.times,
  });

  final String language;
  final String length;
  final String times;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сегодня учим маленькими шагами',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.language, label: language),
                _InfoChip(icon: Icons.short_text, label: length),
                _InfoChip(
                  icon: Icons.notifications_active_outlined,
                  label: times.isEmpty ? 'Нет времени' : times,
                ),
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
  const _EmptyTopics({required this.onAdd});

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
              'Добавь первую тему',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Напиши то, что давно хотел понять: космос, бизнес, история, английский или любую другую идею.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Добавить тему'),
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
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Topic topic;
  final int factCount;
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
        title: Text(
          topic.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          topic.enabled
              ? '$factCount фактов · уведомления включены'
              : '$factCount фактов · уведомления выключены',
        ),
        leading: Switch(
          value: topic.enabled,
          onChanged: onToggle,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('Переименовать'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Удалить'),
            ),
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
  final value = await showDialog<String>(
    context: context,
    builder: (_) => _TopicDialog(initialTitle: existingTopic?.title),
  );

  if (value == null || value.isEmpty) {
    return;
  }
  if (existingTopic == null) {
    await controller.addTopic(value);
  } else {
    await controller.renameTopic(existingTopic.id, value);
  }
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog({this.initialTitle});

  final String? initialTitle;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTitle != null;
    final title = isEditing ? 'Переименовать тему' : 'Новая тема';
    final action = isEditing ? 'Сохранить' : 'Добавить';

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: _textController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Тема',
          hintText: 'Например: космос',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(action),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_textController.text.trim());
  }
}
