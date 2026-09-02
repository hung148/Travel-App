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
    this.embedded = false,
  });

  final List<DestinationDraft> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final List<TravelLegDraft> travelLegs;
  final ValueChanged<TravelLegDraft> onEditTravelLeg;
  final ValueChanged<String> onRemove;
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
              onSelected: (_) => onSelected(destinations[index].id),
              onDeleted: destinations.length > 1
                  ? () => onRemove(destinations[index].id)
                  : null,
              deleteIcon: const Icon(Icons.close_rounded, size: 17),
              deleteButtonTooltipMessage: 'Remove destination',
              avatar: CircleAvatar(child: Text('${index + 1}')),
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
