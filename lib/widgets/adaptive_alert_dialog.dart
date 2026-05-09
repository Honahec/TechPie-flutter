import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

const _presenterChannel = MethodChannel('techpie/native_glass_presenter');

Future<T?> showAdaptiveAlertDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<AdaptiveAlertAction<T>> actions,
}) {
  final usesIosDialog = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  if (usesIosDialog) {
    return _showNativeIosAlert<T>(
      title: title,
      message: message,
      actions: actions,
      fallbackContext: context,
    );
  }

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

Future<T?> _showNativeIosAlert<T>({
  required String title,
  required String message,
  required List<AdaptiveAlertAction<T>> actions,
  required BuildContext fallbackContext,
}) async {
  try {
    final result = await _presenterChannel.invokeMethod<dynamic>('showAlert', {
      'title': title,
      'message': message,
      'actions': [
        for (final action in actions)
          {
            'label': action.label,
            'value': action.value,
            'isDestructive': action.isDestructive,
            'isDefault': action.isDefault,
          },
      ],
    });

    return result as T?;
  } on PlatformException {
    if (!fallbackContext.mounted) return null;

    return showDialog<T>(
      context: fallbackContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          for (final action in actions)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, action.value),
              child: Text(action.label),
            ),
        ],
      ),
    );
  }
}
