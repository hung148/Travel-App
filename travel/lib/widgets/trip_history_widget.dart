import 'package:flutter/material.dart';
import '../../models/trip/trip.dart';

class TripHistoryWidget extends StatelessWidget {
  final List<Trip> trips;
  final Function(Trip) onTripTap;

  const TripHistoryWidget({
    super.key,
    required this.trips,
    required this.onTripTap,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const Center(
        child: Text('No trips yet'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(trip.destination),
            subtitle: Text('${trip.days} days, \$${trip.budget}'),
            trailing: trip.rating != null ? Text('⭐ ${trip.rating}') : null,
            onTap: () => onTripTap(trip),
          ),
        );
      },
    );
  }
}