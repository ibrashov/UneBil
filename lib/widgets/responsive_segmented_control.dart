import 'package:flutter/material.dart';

class ResponsiveSegment<T> {
  const ResponsiveSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class ResponsiveSegmentedControl<T> extends StatelessWidget {
  const ResponsiveSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<ResponsiveSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(10));

    return Semantics(
      container: true,
      child: Material(
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / segments.length;
            final compact = segmentWidth < 92;
            return SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < segments.length; index++) ...[
                    if (index > 0)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colors.outline,
                      ),
                    Expanded(
                      child: _SegmentItem<T>(
                        segment: segments[index],
                        selected: segments[index].value == selected,
                        compact: compact,
                        onTap: onSelectionChanged,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SegmentItem<T> extends StatelessWidget {
  const _SegmentItem({
    required this.segment,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final ResponsiveSegment<T> segment;
  final bool selected;
  final bool compact;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: segment.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        child: InkWell(
          onTap: () => onTap(segment.value),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: compact ? 13 : 16,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: Icon(
                      Icons.check,
                      size: compact ? 13 : 16,
                      color: foreground,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 2 : 4),
                Flexible(
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontSize: compact ? 12 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
