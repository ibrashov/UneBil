import 'package:flutter/material.dart';

enum HomeLearningMode { facts, check }

class FactsCheckSegmentedControl extends StatelessWidget {
  const FactsCheckSegmentedControl({
    super.key,
    required this.selected,
    required this.factsLabel,
    required this.checkLabel,
    required this.onChanged,
  });

  final HomeLearningMode selected;
  final String factsLabel;
  final String checkLabel;
  final ValueChanged<HomeLearningMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                AnimatedAlign(
                  alignment: selected == HomeLearningMode.facts
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: constraints.maxWidth / 2,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _ModeButton(
                      label: factsLabel,
                      selected: selected == HomeLearningMode.facts,
                      onTap: () => onChanged(HomeLearningMode.facts),
                    ),
                    _ModeButton(
                      label: checkLabel,
                      selected: selected == HomeLearningMode.check,
                      onTap: () => onChanged(HomeLearningMode.check),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: theme.textTheme.labelLarge!.copyWith(
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}
