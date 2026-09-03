import 'package:flutter/material.dart';

import '../../models/planner_result.dart';
import '../../models/hotel_stay.dart';
import '../../service/planner/daily_time_schedule_service.dart';
import '../../widgets/place_photo.dart';
import 'review_widget.dart';
import '../plan_trip/models/destination_draft.dart';
import 'multi_destination_review.dart';

class SummaryPage extends StatelessWidget {
  final PlannerResult? result;
  final String? destination;
  final DateTimeRange? dates;
  final int travelers;
  final List<DestinationDraft>? destinations;

  const SummaryPage({
    super.key,
    this.result,
    this.destination,
    this.dates,
    this.travelers = 1,
    this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final plan = result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review your plan'),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: destinations != null && destinations!.isNotEmpty
          ? MultiDestinationReview(
              destinations: destinations!,
              travelers: travelers,
            )
          : plan == null
          ? _EmptyReview(
              onPlanTrip: () => Navigator.pushNamed(context, '/plan-trip'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TripHeader(
                        destination: destination ?? 'Your trip',
                        dates: dates,
                        travelers: travelers,
                        result: plan,
                      ),
                      if (plan.hotel != null) ...[
                        const SizedBox(height: 18),
                        _HotelReview(hotel: plan.hotel!),
                      ],
                      const SizedBox(height: 18),
                      _Metrics(result: plan),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final budget = _BudgetBreakdown(result: plan);
                          final validation = _ValidationReview(result: plan);
                          if (constraints.maxWidth < 820) {
                            return Column(
                              children: [
                                budget,
                                const SizedBox(height: 14),
                                validation,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: budget),
                              const SizedBox(width: 14),
                              Expanded(child: validation),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Day-by-day itinerary',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      for (final day in plan.days) ...[
                        _DayReview(
                          day: day,
                          restMinutes: plan.profile.restMinutesPerDay,
                          hotel: plan.hotel,
                        ),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 6),
                      const ReviewWidget(),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Back to edit'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Plan confirmed for this session.',
                                    ),
                                  ),
                                ),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            label: const Text('Confirm plan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  final String destination;
  final DateTimeRange? dates;
  final int travelers;
  final PlannerResult result;

  const _TripHeader({
    required this.destination,
    required this.dates,
    required this.travelers,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return _ReviewCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.location_on_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateText(dates)} • ${result.days.length} days • '
                  '${result.profile.label} plan • $travelers '
                  '${travelers == 1 ? 'traveler' : 'travelers'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateText(DateTimeRange? dates) {
    if (dates == null) return 'Dates not selected';
    String format(DateTime value) =>
        '${value.month}/${value.day}/${value.year}';
    return '${format(dates.start)} – ${format(dates.end)}';
  }
}

class _Metrics extends StatelessWidget {
  final PlannerResult result;

  const _Metrics({required this.result});

  @override
  Widget build(BuildContext context) {
    final stopCount = result.days.fold<int>(
      0,
      (total, day) => total + day.places.length,
    );
    final items = [
      (
        'Total budget',
        '\$${result.budgetAllocation.total.toStringAsFixed(0)}',
        Icons.account_balance_wallet_outlined,
      ),
      (
        'Planned expense',
        '\$${result.totalEstimatedTripCost.toStringAsFixed(0)}',
        Icons.local_activity_outlined,
      ),
      ('Planned stops', '$stopCount', Icons.place_outlined),
      (
        'Plan status',
        result.validation.warnings.isEmpty
            ? 'Ready'
            : '${result.validation.warnings.length} warnings',
        Icons.fact_check_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 700
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _ReviewCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        item.$3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              item.$2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HotelReview extends StatelessWidget {
  final HotelStay hotel;

  const _HotelReview({required this.hotel});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Hotel and route anchor',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.hotel_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotel.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (hotel.address.isNotEmpty) Text(hotel.address),
                const SizedBox(height: 6),
                Text(
                  '${hotel.nights} nights • ${hotel.rooms} rooms • '
                  '\$${hotel.nightlyRate.toStringAsFixed(0)} per room/night',
                ),
                Text(
                  'Accommodation total: \$${hotel.totalCost.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetBreakdown extends StatelessWidget {
  final PlannerResult result;

  const _BudgetBreakdown({required this.result});

  @override
  Widget build(BuildContext context) {
    final allocation = result.budgetAllocation;
    final rows = [
      ('Accommodation', allocation.accommodation, Icons.bed_outlined),
      ('Food', allocation.food, Icons.restaurant_outlined),
      (
        'Transportation',
        allocation.transportation,
        Icons.directions_transit_outlined,
      ),
      ('Activities', allocation.activities, Icons.confirmation_number_outlined),
      ('Buffer', allocation.buffer, Icons.savings_outlined),
    ];
    return _SectionCard(
      title: 'Budget allocation',
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(row.$3, size: 19),
                  const SizedBox(width: 9),
                  Expanded(child: Text(row.$1)),
                  Text(
                    '\$${row.$2.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ValidationReview extends StatelessWidget {
  final PlannerResult result;

  const _ValidationReview({required this.result});

  @override
  Widget build(BuildContext context) {
    final warnings = result.validation.warnings;
    return _SectionCard(
      title: warnings.isEmpty ? 'Plan checks passed' : 'Review warnings',
      child: warnings.isEmpty
          ? const Row(
              children: [
                Icon(Icons.verified_rounded, color: Colors.green),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No budget, time, meal, duplicate, or schedule problems found.',
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final issue in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 19),
                        const SizedBox(width: 8),
                        Expanded(child: Text(issue.message)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DayReview extends StatelessWidget {
  final PlannerDay day;
  final int restMinutes;
  final HotelStay? hotel;

  const _DayReview({
    required this.day,
    required this.restMinutes,
    required this.hotel,
  });

  @override
  Widget build(BuildContext context) {
    final scheduledStops = const DailyTimeScheduleService().schedule(
      day.places,
    );
    return _SectionCard(
      title: 'Day ${day.dayNumber}',
      trailing: Wrap(
        spacing: 8,
        children: [
          _SmallBadge(
            icon: Icons.schedule_outlined,
            text: _minutes(day.estimatedVisitMinutes),
          ),
          _SmallBadge(
            icon: Icons.payments_outlined,
            text: '\$${day.estimatedCost.toStringAsFixed(0)}',
          ),
        ],
      ),
      child: day.places.isEmpty
          ? const Text('Free day — no activities selected.')
          : Column(
              children: [
                if (hotel != null) ...[
                  _HotelStopRow(label: 'Start at ${hotel!.name}'),
                  const Divider(height: 22),
                ],
                for (int index = 0; index < day.places.length; index++) ...[
                  Builder(
                    builder: (context) {
                      final item = day.places[index];
                      final scheduled = scheduledStops[index];
                      return _StopRow(
                        number: index + 1,
                        time: scheduled.formattedStartTime,
                        title: item.place.name,
                        role: scheduled.roleLabel,
                        category: item.place.category,
                        minutes: item.place.estimatedVisitMinutes,
                        cost: item.place.estimatedCost,
                        photoUrl: item.place.photoUrl,
                      );
                    },
                  ),
                  if (index != day.places.length - 1) const Divider(height: 22),
                ],
                if (hotel != null) ...[
                  const Divider(height: 22),
                  _HotelStopRow(label: 'Return to ${hotel!.name}'),
                ],
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.free_breakfast_rounded, size: 20),
                    const SizedBox(width: 9),
                    Text(
                      'Rest / free time • ${_minutes(restMinutes)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _minutes(int total) {
    final hours = total ~/ 60;
    final minutes = total % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }
}

class _HotelStopRow extends StatelessWidget {
  final String label;

  const _HotelStopRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.hotel_rounded, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final int number;
  final String time;
  final String title;
  final String role;
  final String category;
  final int minutes;
  final double cost;
  final String? photoUrl;

  const _StopRow({
    required this.number,
    required this.time,
    required this.title,
    required this.role,
    required this.category,
    required this.minutes,
    required this.cost,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: Text(
            '$number',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            time,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        PlacePhoto(
          placeName: title,
          photoUrl: photoUrl,
          width: 68,
          height: 68,
          borderRadius: 14,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$role • ${category.replaceAll('_', ' ')} • $minutes min',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '\$${cost.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(text),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return _ReviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (trailing != null) ...[const SizedBox(height: 8), trailing!],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ReviewCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.78),
        ),
      ),
      child: child,
    );
  }
}

class _EmptyReview extends StatelessWidget {
  final VoidCallback onPlanTrip;

  const _EmptyReview({required this.onPlanTrip});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_outlined, size: 58),
            const SizedBox(height: 14),
            const Text(
              'No generated plan to review.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onPlanTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan a trip'),
            ),
          ],
        ),
      ),
    );
  }
}
