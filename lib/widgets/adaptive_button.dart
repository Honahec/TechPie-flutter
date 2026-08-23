import 'package:flutter/material.dart';

enum AdaptiveButtonRole { prominent, standard, plain, destructive }

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.subtitle,
    this.role = AdaptiveButtonRole.standard,
    this.loading = false,
    this.width,
    this.height,
    this.accessibilityLabel,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final String? subtitle;
  final AdaptiveButtonRole role;
  final bool loading;
  final double? width;
  final double? height;
  final String? accessibilityLabel;

  @override
  Widget build(BuildContext context) => _buildMaterialButton(context);

  Widget _buildMaterialButton(BuildContext context) {
    final buttonLabel = label;
    if (buttonLabel == null || buttonLabel.isEmpty) {
      return IconButton.filled(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
      );
    }

    final foreground = role == AdaptiveButtonRole.destructive
        ? Theme.of(context).colorScheme.error
        : null;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(buttonLabel),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(height ?? 56)),
      foregroundColor:
          foreground == null ? null : WidgetStatePropertyAll(foreground),
    );
    final callback = loading ? null : onPressed;

    return switch (role) {
      AdaptiveButtonRole.prominent =>
        FilledButton(onPressed: callback, style: style, child: child),
      AdaptiveButtonRole.standard => FilledButton.tonal(
          onPressed: callback,
          style: style,
          child: child,
        ),
      AdaptiveButtonRole.plain ||
      AdaptiveButtonRole.destructive =>
        TextButton(onPressed: callback, style: style, child: child),
    };
  }
}
