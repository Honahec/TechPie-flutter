import 'package:flutter/material.dart';

class AdaptiveAlertAction<T> {
  const AdaptiveAlertAction({
    required this.label,
    this.value,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;
  final T? value;
  final bool isDestructive;
  final bool isDefault;
}

Future<T?> showAdaptiveAlertDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<AdaptiveAlertAction<T>> actions,
}) {
  return _showFlutterAlertDialog<T>(
    context: context,
    title: title,
    message: message,
    actions: _normalizeActions(actions),
  );
}

List<AdaptiveAlertAction<T>> _normalizeActions<T>(
  List<AdaptiveAlertAction<T>> actions,
) {
  final normalized = [
    for (final action in actions)
      if (action.label.trim().isNotEmpty)
        AdaptiveAlertAction<T>(
          label: action.label.trim(),
          value: action.value,
          isDestructive: action.isDestructive,
          isDefault: action.isDefault,
        ),
  ];

  if (normalized.isNotEmpty) return normalized;

  return [AdaptiveAlertAction<T>(label: 'OK', isDefault: true)];
}

Future<T?> _showFlutterAlertDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<AdaptiveAlertAction<T>> actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        for (final action in actions)
          action.isDefault && !action.isDestructive
              ? FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, action.value),
                  child: Text(action.label),
                )
              : TextButton(
                  onPressed: () => Navigator.pop(dialogContext, action.value),
                  child: Text(
                    action.label,
                    style: action.isDestructive
                        ? TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          )
                        : null,
                  ),
                ),
      ],
    ),
  );
}
