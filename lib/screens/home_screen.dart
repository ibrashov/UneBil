import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/interface_language.dart';
import '../models/notification_interval.dart';
import '../models/topic.dart';
import '../services/app_controller.dart';
import '../widgets/check_topic_card.dart';
import '../widgets/facts_check_segmented_control.dart';
import 'settings_screen.dart';
import 'topic_check_screen.dart';
import 'topic_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeLearningMode _mode = HomeLearningMode.facts;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
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
              : _HomeContent(
                  controller: controller,
                  mode: _mode,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                ),
          floatingActionButton: _mode == HomeLearningMode.facts
              ? FloatingActionButton.extended(
                  onPressed: () => _showTopicDialog(context, controller),
                  icon: const Icon(Icons.add),
                  label: Text(strings.topic),
                )
              : null,
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.controller,
    required this.mode,
    required this.onModeChanged,
  });

  final AppController controller;
  final HomeLearningMode mode;
  final ValueChanged<HomeLearningMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
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
        if (controller.dataLoadFailed) ...[
          Card(
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
                      strings.dataLoadError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FactsCheckSegmentedControl(
          selected: mode,
          factsLabel: strings.factsTab,
          checkLabel: strings.checkTab,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          child: mode == HomeLearningMode.facts
              ? _FactsTopicList(
                  key: const ValueKey('factsMode'),
                  controller: controller,
                  strings: strings,
                )
              : _CheckTopicList(
                  key: const ValueKey('checkMode'),
                  controller: controller,
                  strings: strings,
                  onReturnToFacts: () => onModeChanged(HomeLearningMode.facts),
                ),
        ),
      ],
    );
  }
}

class _FactsTopicList extends StatelessWidget {
  const _FactsTopicList({
    super.key,
    required this.controller,
    required this.strings,
  });

  final AppController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final topics = controller.topics;
    if (topics.isEmpty) {
      return _EmptyTopics(
        strings: strings,
        onAdd: () => _showTopicDialog(context, controller),
      );
    }
    return Column(
      children: topics
          .map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopicTile(
                topic: topic,
                factCount: controller.factsForTopic(topic.id).length,
                unreadCount: controller.unreadCountForTopic(topic.id),
                intervalLabel: topic.notificationInterval.label(
                  controller.settings.interfaceLanguage!,
                ),
                strings: strings,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TopicDetailScreen(
                      controller: controller,
                      topicId: topic.id,
                    ),
                  ),
                ),
                onToggle: (enabled) =>
                    controller.toggleTopic(topic.id, enabled),
                onEdit: () =>
                    _showTopicDialog(context, controller, existingTopic: topic),
                onDelete: () => controller.deleteTopic(topic.id),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CheckTopicList extends StatelessWidget {
  const _CheckTopicList({
    super.key,
    required this.controller,
    required this.strings,
    required this.onReturnToFacts,
  });

  final AppController controller;
  final AppStrings strings;
  final VoidCallback onReturnToFacts;

  @override
  Widget build(BuildContext context) {
    final topics = controller.topics
        .where((topic) => controller.factsForTopic(topic.id).isNotEmpty)
        .toList(growable: false);
    if (topics.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Icon(
                Icons.psychology_alt_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                strings.noFactsAvailable,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(strings.noCheckTopicsBody, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onReturnToFacts,
                child: Text(strings.returnToFacts),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: topics
          .map((topic) {
            final facts = controller.factsForTopic(topic.id);
            final checked = controller.checkedCountForTopic(topic.id);
            final unread = controller.unreadCountForTopic(topic.id);
            final reviewStatus = checked == 0
                ? strings.readyToReview
                : checked < facts.length
                ? strings.continueChecking
                : strings.allFactsChecked;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CheckTopicCard(
                title: topic.title,
                factStatus: strings.factsReadStatus(facts.length, unread),
                reviewStatus: checked > 0
                    ? '${strings.checkedStatus(checked)} · $reviewStatus'
                    : reviewStatus,
                progress: facts.isEmpty ? 0 : checked / facts.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TopicCheckScreen(
                      controller: controller,
                      topicId: topic.id,
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
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
    required this.unreadCount,
    required this.intervalLabel,
    required this.strings,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Topic topic;
  final int factCount;
  final int unreadCount;
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
          '${strings.factsReadStatus(factCount, unreadCount)} · '
          '${topic.enabled ? intervalLabel : strings.notificationsOff}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
