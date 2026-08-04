import 'package:flutter/material.dart';

class RecallInputCard extends StatelessWidget {
  const RecallInputCard({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.readOnly,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('recallTextField'),
              controller: controller,
              readOnly: readOnly,
              minLines: 5,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
      ),
    );
  }
}

class OriginalFactCard extends StatelessWidget {
  const OriginalFactCard({
    super.key,
    required this.label,
    required this.title,
    required this.body,
  });

  final String label;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(body, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class ReviewResultButtons extends StatelessWidget {
  const ReviewResultButtons({
    super.key,
    required this.rememberedLabel,
    required this.reviewAgainLabel,
    required this.onRemembered,
    required this.onReviewAgain,
  });

  final String rememberedLabel;
  final String reviewAgainLabel;
  final VoidCallback onRemembered;
  final VoidCallback onReviewAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('rememberedButton'),
          onPressed: onRemembered,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(rememberedLabel),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('reviewAgainButton'),
          onPressed: onReviewAgain,
          icon: const Icon(Icons.replay),
          label: Text(reviewAgainLabel),
        ),
      ],
    );
  }
}

class CheckSessionSummary extends StatelessWidget {
  const CheckSessionSummary({
    super.key,
    required this.title,
    required this.checkedLabel,
    required this.rememberedLabel,
    required this.difficultLabel,
    required this.returnLabel,
    required this.reviewDifficultLabel,
    required this.hasDifficultFacts,
    required this.onReturn,
    required this.onReviewDifficult,
  });

  final String title;
  final String checkedLabel;
  final String rememberedLabel;
  final String difficultLabel;
  final String returnLabel;
  final String reviewDifficultLabel;
  final bool hasDifficultFacts;
  final VoidCallback onReturn;
  final VoidCallback onReviewDifficult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt,
                size: 34,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 18),
            Text(checkedLabel),
            const SizedBox(height: 6),
            Text(rememberedLabel),
            const SizedBox(height: 6),
            Text(difficultLabel),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onReturn,
                child: Text(returnLabel),
              ),
            ),
            if (hasDifficultFacts) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onReviewDifficult,
                  child: Text(reviewDifficultLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
