import 'package:flutter/material.dart';

class ChipSection extends StatelessWidget {
    final String label;
    final List<String> options;
    final String? selected;
    final ValueChanged<String> onSelected;

    const ChipSection({
        super.key,
        required this.label,
        required this.options,
        required this.selected,
        required this.onSelected,
    });

    @override
    Widget build(BuildContext context) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                        return ChoiceChip(
                            key: Key('chip_$option'),
                            label: Text(option),
                            selected: option == selected,
                            onSelected: (_) => onSelected(option),
                        );
                    }).toList(),
                ),
            ],
        );
    }
}