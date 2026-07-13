import 'package:flutter/material.dart';

import '../models/learning_fact.dart';

class FactDetailScreen extends StatelessWidget {
  const FactDetailScreen({super.key, required this.fact});

  final LearningFact fact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fact.topicTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(fact.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SelectableText(
            fact.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
