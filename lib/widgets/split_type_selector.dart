import 'package:flutter/material.dart';

import '../models/split_type.dart';

class SplitTypeSelector extends StatelessWidget {
  final SplitType value;
  final ValueChanged<SplitType> onChanged;

  const SplitTypeSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SplitType>(
      segments: const [
        ButtonSegment(value: SplitType.equal, label: Text('Equal')),
        ButtonSegment(value: SplitType.custom, label: Text('Custom')),
        ButtonSegment(value: SplitType.percentage, label: Text('Percentage')),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
