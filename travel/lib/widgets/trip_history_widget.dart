import 'package:flutter/material.dart';
import '../../models/trip/trip.dart';

class TripHistoryWidget extends StatelessWidget {
  final List<Trip> trips;
  final Function(Trip) onTripTap;
  final Future<void> Function(Trip)? onTripDelete;

  const TripHistoryWidget({
    super.key,
    required this.trips,
    required this.onTripTap,
    this.onTripDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const Center(child: Text('No trips yet'));
    }

    final sortedTrips = List<Trip>.of(trips)
      ..sort((a, b) {
        final aDate = a.startDate ?? a.createdAt;
        final bDate = b.startDate ?? b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = sortedTrips[index];
        final dateLabel = trip.startDate == null
            ? 'Dates not set'
            : '${MaterialLocalizations.of(context).formatMediumDate(trip.startDate!)} – '
                '${MaterialLocalizations.of(context).formatMediumDate(trip.endDate ?? trip.startDate!)}';
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(trip.destination),
            subtitle: Text(
              '$dateLabel • ${trip.days} days • \$${trip.budget.toStringAsFixed(0)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trip.rating != null) Text('⭐ ${trip.rating}'),
                if (onTripDelete != null)
                  IconButton(
                    tooltip: 'Delete trip',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => onTripDelete!(trip),
                  ),
              ],
            ),
            onTap: () => onTripTap(trip),
          ),
        );
      },
    );
  }
}
