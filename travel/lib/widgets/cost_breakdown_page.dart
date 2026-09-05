import 'package:flutter/material.dart';

import '../models/cost_breakdown.dart';
import '../models/planner_result.dart';

/// Opens the "where does this number come from" page.
///
/// The itinerary shows one total and no per-stop prices; this is the answer
/// when someone wants to check it. Reads [CostBreakdown], the same object the
/// AI assistant answers from, so the two can never disagree.
Future<void> showCostBreakdown(BuildContext context, PlannerResult result) {
  final breakdown = CostBreakdown.from(result);
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => CostBreakdownPage(breakdown: breakdown),
    ),
  );
}

class CostBreakdownPage extends StatelessWidget {
  final CostBreakdown breakdown;

  const CostBreakdownPage({super.key, required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Scaffold(
      appBar: AppBar(
        title: const Text('How this total is calculated'),
      ),
      body: Center(
        child: ConstrainedBox(
          // A reading column. A full-width list of amounts on a desktop
          // monitor is harder to follow, not easier.
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
            children: [
              Text(
                'Shown ${breakdown.modeLabel}, in ${breakdown.currencyCode}.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 18),

              _TotalRow(
                label: 'Total estimated trip expense',
                value: breakdown.money(breakdown.total),
                strong: true,
              ),
              if (breakdown.comparableToBudget) ...[
                const SizedBox(height: 4),
                _TotalRow(
                  label: 'Your budget',
                  value: breakdown.money(breakdown.budgetTotal),
                ),
                _TotalRow(
                  label: breakdown.remainingBudget >= 0
                      ? 'Left over'
                      : 'Over budget',
                  value: breakdown.money(breakdown.remainingBudget.abs()),
                  valueColor: breakdown.remainingBudget >= 0
                      ? null
                      : theme.colorScheme.error,
                ),
              ],

              const Divider(height: 32),

              _SectionLabel('WHAT MAKES IT UP', color: muted),
              const SizedBox(height: 10),

              if (breakdown.hotelName != null)
                _LineItem(
                  icon: Icons.hotel_outlined,
                  title: 'Hotel',
                  amount: breakdown.money(breakdown.hotelTotal),
                  detail:
                      '${breakdown.hotelName} • '
                      '${breakdown.money(breakdown.hotelNightlyRate)} per room '
                      'per night × ${breakdown.hotelNights} '
                      '${breakdown.hotelNights == 1 ? 'night' : 'nights'} × '
                      '${breakdown.hotelRooms} '
                      '${breakdown.hotelRooms == 1 ? 'room' : 'rooms'}'
                      '${breakdown.hotelRateEstimated ? ' • rate estimated' : ''}',
                ),
              _LineItem(
                icon: Icons.restaurant_outlined,
                title: 'Meals',
                amount: breakdown.money(breakdown.mealTotal),
                detail: '${breakdown.mealStopCount} stops',
              ),
              _LineItem(
                icon: Icons.confirmation_number_outlined,
                title: 'Activities',
                amount: breakdown.money(breakdown.activityTotal),
                detail: '${breakdown.activityStopCount} stops',
              ),

              const Divider(height: 32),

              _SectionLabel('STOP BY STOP', color: muted),

              for (final day in breakdown.days)
                if (day.stops.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Day ${day.dayNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        breakdown.money(day.total),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final stop in day.stops)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stop.name),
                                Text(
                                  stop.sourceDescription,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            // The tilde is the honest part: it marks a number
                            // we derived rather than one the place published.
                            '${stop.isEstimated ? '≈' : ''}'
                            '${breakdown.money(stop.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],

              const Divider(height: 32),

              if (breakdown.estimatedStopCount > 0)
                _Note(
                  icon: Icons.info_outline_rounded,
                  text:
                      '${breakdown.estimatedStopCount} of '
                      '${breakdown.stopCount} stops are estimates rather than '
                      'published prices, so the real total will differ.',
                ),
              if (breakdown.unpricedStopCount > 0)
                _Note(
                  icon: Icons.help_outline_rounded,
                  text:
                      '${breakdown.unpricedStopCount} '
                      '${breakdown.unpricedStopCount == 1 ? 'stop has' : 'stops have'} '
                      'no price data at all and count as zero here.',
                ),
              if (breakdown.calibrationNote != null)
                _Note(
                  icon: Icons.calculate_outlined,
                  text: breakdown.calibrationNote!,
                ),
              const _Note(
                icon: Icons.directions_transit_outlined,
                text: 'Transport between stops is not costed yet.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        color: color,
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
      fontSize: strong ? 20 : 14,
      color: valueColor,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amount;
  final String detail;

  const _LineItem({
    required this.icon,
    required this.title,
    required this.amount,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.65);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
