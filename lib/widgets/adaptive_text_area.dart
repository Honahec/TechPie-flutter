import 'package:flutter/material.dart';

class AdaptiveTextArea extends StatelessWidget {
  const AdaptiveTextArea({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(hintText: placeholder),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
    );
  }
}
