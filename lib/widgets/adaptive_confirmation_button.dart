import 'dart:async';

import 'package:flutter/material.dart';

import 'adaptive_alert_dialog.dart';

class AdaptiveConfirmationButton extends StatelessWidget {
  const AdaptiveConfirmationButton({
    super.key,
    this.label,
    required this.confirmTitle,
    required this.confirmLabel,
    required this.onConfirmed,
    this.icon = Icons.link_off,
    this.destructive = false,
    this.width,
    this.height = 44.0,
  });

  final String? label;
  final String confirmTitle;
  final String confirmLabel;
  final VoidCallback onConfirmed;
  final IconData icon;
  final bool destructive;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null && label!.isNotEmpty;
    final constrainedHeight = height < 44.0 ? 44.0 : height;
    void callback() => unawaited(_confirm(context));

    return SizedBox(
      width: width,
      height: constrainedHeight,
      child: hasLabel
          ? TextButton.icon(
              onPressed: callback,
              icon: Icon(icon, size: 18),
              label: Text(label!),
            )
          : IconButton(
              onPressed: callback,
              icon: Icon(icon, size: 18),
              tooltip: confirmTitle,
            ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: confirmTitle,
      message: '',
      actions: [
        const AdaptiveAlertAction<bool>(label: '取消', value: false),
        AdaptiveAlertAction<bool>(
          label: confirmLabel,
          value: true,
          isDestructive: destructive,
          isDefault: !destructive,
        ),
      ],
    );
    if (confirmed == true) onConfirmed();
  }
}
