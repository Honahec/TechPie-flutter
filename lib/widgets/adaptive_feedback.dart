import "package:flutter/material.dart";

final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

enum AdaptiveFeedbackStyle { info, success, error }

void showAdaptiveFeedback({
  BuildContext? context,
  required String message,
  AdaptiveFeedbackStyle style = AdaptiveFeedbackStyle.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = context != null
      ? ScaffoldMessenger.maybeOf(context)
      : rootMessengerKey.currentState;
  if (messenger == null) return;

  final theme = messenger.context.mounted
      ? Theme.of(messenger.context)
      : ThemeData.fallback();
  final feedbackStyle = _FeedbackStyle.from(theme, style);

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: feedbackStyle.backgroundColor,
        content: Row(
          children: [
            Icon(feedbackStyle.icon, color: feedbackStyle.foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: feedbackStyle.foregroundColor),
              ),
            ),
          ],
        ),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}

class _FeedbackStyle {
  const _FeedbackStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  static _FeedbackStyle from(ThemeData theme, AdaptiveFeedbackStyle style) {
    final colors = theme.colorScheme;

    return switch (style) {
      AdaptiveFeedbackStyle.success => _FeedbackStyle(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          icon: Icons.check_circle_outline,
        ),
      AdaptiveFeedbackStyle.error => _FeedbackStyle(
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.onErrorContainer,
          icon: Icons.error_outline,
        ),
      AdaptiveFeedbackStyle.info => _FeedbackStyle(
          backgroundColor: colors.inverseSurface,
          foregroundColor: colors.onInverseSurface,
          icon: Icons.info_outline,
        ),
    };
  }
}
