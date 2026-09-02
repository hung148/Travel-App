import 'package:flutter/material.dart';

import '../models/destination_draft.dart';
import '../models/travel_leg_draft.dart';

class DestinationSelector extends StatelessWidget {
  const DestinationSelector({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
    this.travelLegs = const [],
    required this.onEditTravelLeg,
  });

  final List<DestinationDraft> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final List<TravelLegDraft> travelLegs;
  final ValueChanged<TravelLegDraft> onEditTravelLeg;

  TravelLegDraft? _legAfter(String destinationId) {
    for (final leg in travelLegs) {
      if (leg.fromDestinationId == destinationId) return leg;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var index = 0; index < destinations.length; index++) ...[
                  ChoiceChip(
                    selected: destinations[index].id == selectedId,
                    onSelected: (_) => onSelected(destinations[index].id),
                    avatar: CircleAvatar(child: Text('${index + 1}')),
                    label: Text(destinations[index].destination),
                  ),
                  if (_legAfter(destinations[index].id) case final leg?) ...[
                    const Icon(Icons.arrow_forward_rounded),
                    ActionChip(
                      avatar: Icon(
                        leg.mode == TravelMode.flight
                            ? Icons.flight_rounded
                            : Icons.directions_car_rounded,
                        size: 18,
                      ),
                      label: Text(
                        '${leg.mode.name} • ${leg.durationHours.toStringAsFixed(1)}h'
                        '${leg.transitDays > 0 ? ' • ${leg.transitDays} transit days' : ''}',
                      ),
                      onPressed: () => onEditTravelLeg(leg),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ],
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add destination'),
                  onPressed: onAdd,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
