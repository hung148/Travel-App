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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No trips yet',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return GestureDetector(
          onTap: () => onTripTap(trip),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Trip icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: trip.status == 'completed'
                        ? const Color(0xFF34C98B).withValues(alpha: 0.1)
                        : const Color(0xFF6B8CFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      trip.status == 'completed' ? '✓' : '📅',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Trip info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.destination,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${trip.days} days • \$${trip.budget}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8892A4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating or status
                if (trip.status == 'completed' && trip.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFB800), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.rating}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    trip.status[0].toUpperCase() + trip.status.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trip.status == 'completed'
                          ? const Color(0xFF34C98B)
                          : const Color(0xFF6B8CFF),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
