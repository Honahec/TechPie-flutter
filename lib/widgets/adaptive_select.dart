import 'package:flutter/material.dart';

class AdaptiveSelectOption {
  const AdaptiveSelectOption({required this.value, required this.label});

  final String value;
  final String label;
}

class AdaptiveSelect extends StatelessWidget {
  const AdaptiveSelect({
    super.key,
    required this.options,
    required this.onChanged,
    this.value,
    this.placeholder = 'Select',
    this.width = 150,
    this.height = 44,
  });

  final List<AdaptiveSelectOption> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value:
                options.any((option) => option.value == value) ? value : null,
            hint: Text(placeholder),
            items: [
              for (final option in options)
                DropdownMenuItem<String>(
                  value: option.value,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (selection) {
              if (selection != null) onChanged(selection);
            },
          ),
        ),
      ),
    );
  }
}
