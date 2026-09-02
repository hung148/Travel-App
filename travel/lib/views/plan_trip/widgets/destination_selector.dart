import 'package:flutter/material.dart';

import '../models/destination_draft.dart';
import '../../../models/trip/travel_leg.dart';

class DestinationSelector extends StatelessWidget {
  const DestinationSelector({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
    this.travelLegs = const [],
    required this.onEditTravelLeg,
    required this.onRemove,
    required this.onEdit,
    this.embedded = false,
  });

  final List<DestinationDraft> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final List<TravelLegDraft> travelLegs;
  final ValueChanged<TravelLegDraft> onEditTravelLeg;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onEdit;
  final bool embedded;

  TravelLegDraft? _legAfter(String destinationId) {
    for (final leg in travelLegs) {
      if (leg.fromDestinationId == destinationId) return leg;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final choices = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < destinations.length; index++) ...[
            InputChip(
              selected: destinations[index].id == selectedId,
              showCheckmark: false,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              side: BorderSide(
                color: destinations[index].id == selectedId
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: destinations[index].id == selectedId ? 2 : 1,
              ),
              elevation: destinations[index].id == selectedId ? 4 : 0,
              pressElevation: 2,
              shadowColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
              labelStyle: TextStyle(
                color: destinations[index].id == selectedId
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: destinations[index].id == selectedId
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              onSelected: (_) {
                final id = destinations[index].id;
                if (id == selectedId) {
                  onEdit(id);
                } else {
                  onSelected(id);
                }
              },
              onDeleted: destinations.length > 1
                  ? () => onRemove(destinations[index].id)
                  : null,
              deleteIcon: const Icon(Icons.close_rounded, size: 17),
              deleteButtonTooltipMessage: 'Remove destination',
              avatar: CircleAvatar(
                backgroundColor: destinations[index].id == selectedId
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: destinations[index].id == selectedId
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              label: Text(destinations[index].destination),
            ),
            if (_legAfter(destinations[index].id) case final leg?) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              ActionChip(
                avatar: Icon(
                  leg.mode == TravelMode.flight
                      ? Icons.flight_rounded
                      : Icons.directions_car_rounded,
                  size: 18,
                ),
                label: Text(
                  '${leg.durationHours.toStringAsFixed(1)}h ${leg.mode.name}'
                  '${leg.transitDays > 0 ? ' • ${leg.transitDays}d transit' : ''}',
                ),
                tooltip: 'Edit travel estimate',
                onPressed: () => onEditTravelLeg(leg),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              const SizedBox(width: 10),
          ],
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add destination'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
    if (embedded) {
      return Container(
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.centerLeft,
        child: choices,
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Destinations',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            choices,
          ],
        ),
      ),
    );
  }
}
