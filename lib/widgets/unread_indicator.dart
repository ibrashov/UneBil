import 'package:flutter/material.dart';

class UnreadIndicator extends StatelessWidget {
  const UnreadIndicator({
    super.key,
    required this.semanticLabel,
    this.size = 9,
  });

  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
