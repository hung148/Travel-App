import 'package:flutter/material.dart';

class ChipSection extends StatelessWidget {
    final String label;
    final List<String> options;
    final String? selected;
    final Set<String> selectedList;
    final ValueChanged<String> onSelected;

    const ChipSection({
        super.key,
        required this.label,
        required this.options,
        required this.selected,
        required this.onSelected,
        required this.selectedList,
    });

    @override
    Widget build(BuildContext context) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                        return selected == null 
                          ? FilterChip(          // FilterChip
                                key: Key('chip_$option'),
                                label: Text(option),
                                selected: selectedList.contains(option),  // set lookup
                                onSelected: (_) => onSelected(option),
                                labelStyle: Theme.of(context).textTheme.bodyMedium,
                            )
                          : ChoiceChip(
                              key: Key('chip_$option'),
                              label: Text(option),
                              selected: option == selected,
                              onSelected: (_) => onSelected(option),
                              labelStyle: Theme.of(context).textTheme.bodyMedium,
                          );
                    }).toList(),
                ),
            ],
        );
    }
}