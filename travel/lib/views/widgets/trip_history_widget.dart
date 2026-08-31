import 'package:flutter/material.dart';
import '../../models/trip/trip.dart';

class TripHistoryWidget extends StatelessWidget {
  final List<Trip> trips;
  final ValueChanged<Trip>? onTripTap;

  const TripHistoryWidget({
    super.key,
    required this.trips,
    this.onTripTap,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: const Column(
          children: [
            Icon(Icons.luggage_outlined, size: 40, color: Color(0xFF7A8499)),
            SizedBox(height: 12),
            Text('No trips yet', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Your saved and completed trips will appear here.'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 650
                ? 2
                : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: trips
              .map((trip) => SizedBox(
                    width: width,
                    child: _TripCard(
                      trip: trip,
                      onTap: () => onTripTap?.call(trip),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const _TripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCompleted = trip.status.toLowerCase() == 'completed';
    final accent = isCompleted ? const Color(0xFF2F9E75) : const Color(0xFF2C7BE5);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.flight_takeoff_rounded, color: accent),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'Upcoming',
                    style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              trip.destination,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('${trip.days} days • Budget \$${trip.budget.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF667085))),
            if (trip.startDate != null) ...[
              const SizedBox(height: 6),
              Text(
                '${trip.startDate!.month}/${trip.startDate!.day}/${trip.startDate!.year}',
                style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (trip.rating != null) ...[
                  const Icon(Icons.star_rounded, color: Color(0xFFF5B942), size: 19),
                  const SizedBox(width: 4),
                  Text('${trip.rating}/5', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
                const Spacer(),
                const Text('View trip', style: TextStyle(color: Color(0xFF2C7BE5), fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 17, color: Color(0xFF2C7BE5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
