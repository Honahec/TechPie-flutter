import 'package:flutter/material.dart';

class AdaptiveSegmentedControl extends StatelessWidget {
  const AdaptiveSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final int value;
  final List<String> segments;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        for (var index = 0; index < segments.length; index++)
          ButtonSegment<int>(value: index, label: Text(segments[index])),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
    );
  }
}
