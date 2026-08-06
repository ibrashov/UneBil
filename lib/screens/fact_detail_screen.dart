import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/app_controller.dart';

class FactDetailScreen extends StatefulWidget {
  const FactDetailScreen({
    super.key,
    required this.controller,
    required this.factId,
  });

  final AppController controller;
  final String factId;

  @override
  State<FactDetailScreen> createState() => _FactDetailScreenState();
}

class _FactDetailScreenState extends State<FactDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.markFactRead(widget.factId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final strings = AppStrings(
          widget.controller.settings.interfaceLanguage!,
        );
        final fact = widget.controller.facts
            .where((candidate) => candidate.id == widget.factId)
            .firstOrNull;
        if (fact == null) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.factsTab)),
            body: Center(child: Text(strings.noFactsAvailable)),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(fact.topicTitle),
            actions: [
              PopupMenuButton<String>(
                onSelected: (_) => fact.isRead
                    ? widget.controller.markFactUnread(fact.id)
                    : widget.controller.markFactRead(fact.id),
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
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                fact.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SelectableText(
                fact.body,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }
}
