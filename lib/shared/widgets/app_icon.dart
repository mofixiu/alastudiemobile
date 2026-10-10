import 'package:flutter/material.dart';

/// Shared Material icon widget for consistent sizing, color, and semantics.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    return Icon(
      icon ?? Icons.circle_outlined,
      size: size ?? theme.size ?? 20,
      color: color ?? theme.color ?? Theme.of(context).colorScheme.onSurface,
      semanticLabel: semanticLabel,
    );
  }
}
