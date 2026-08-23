import 'package:flutter/material.dart';

class AdaptiveTextFieldGroupItem {
  const AdaptiveTextFieldGroupItem({
    required this.controller,
    required this.placeholder,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
}

class AdaptiveTextFieldGroup extends StatelessWidget {
  const AdaptiveTextFieldGroup({super.key, required this.items});

  final List<AdaptiveTextFieldGroupItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          TextField(
            controller: item.controller,
            decoration: InputDecoration(hintText: item.placeholder),
            keyboardType: item.keyboardType,
            textInputAction: item.textInputAction,
            obscureText: item.obscureText,
            enabled: item.enabled,
            onSubmitted: item.onSubmitted,
          ),
      ],
    );
  }
}
