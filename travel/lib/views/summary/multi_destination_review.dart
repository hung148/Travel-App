import 'package:flutter/material.dart';

import '../../core/utils/money.dart';
import '../plan_trip/models/destination_draft.dart';
import '../../widgets/place_photo.dart';
import 'review_widget.dart';

class MultiDestinationReview extends StatelessWidget {
  const MultiDestinationReview({
    super.key,
    required this.destinations,
    required this.travelers,
  });

  final List<DestinationDraft> destinations;
  final int travelers;

  String _date(DateTime value) => '${value.month}/${value.day}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final planned = destinations.where((item) => item.days.isNotEmpty).toList();
    final totalBudget = destinations.fold<double>(
      0,
      (sum, item) => sum + item.budget,
    );
    final hotelTotal = planned.fold<double>(
      0,
      (sum, item) => sum + (item.selectedHotel?.totalCost ?? 0),
    );
    final foodTotal = planned.fold<double>(
      0,
      (sum, item) =>
          sum +
          item.days.fold<double>(
            0,
            (daySum, day) => daySum + day.estimatedFoodCostFor(travelers),
          ),
    );
    final activityTotal = planned.fold<double>(
      0,
      (sum, item) =>
          sum +
          item.days.fold<double>(
            0,
            (daySum, day) => daySum + day.estimatedActivityCostFor(travelers),
          ),
    );
    final estimatedTotal = hotelTotal + foodTotal + activityTotal;
    // Legs can be planned in different currencies. Amounts are never
    // converted, so a combined total is only meaningful when every leg shares
    // one currency.
    final currencies = (planned.isEmpty ? destinations : planned)
        .map((item) => item.currencyCode)
        .toSet();
    final currencyCode = currencies.isEmpty ? Money.defaultCurrencyCode : currencies.first;
    final hasMixedCurrencies = currencies.length > 1;
    final firstDate = destinations
        .where((item) => item.dates != null)
        .map((item) => item.dates!.start)
        .fold<DateTime?>(
          null,
          (min, value) => min == null || value.isBefore(min) ? value : min,
        );
    final lastDate = destinations
        .where((item) => item.dates != null)
        .map((item) => item.dates!.end)
        .fold<DateTime?>(
          null,
          (max, value) => max == null || value.isAfter(max) ? value : max,
        );

    var dayOffset = 0;
    final destinationCards = <Widget>[];
    for (final destination in destinations) {
      final days = destination.days;
      destinationCards.add(
        _ReviewCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      destination.destination.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  // Whether this leg actually has a schedule. The old flag
                  // this read was set by a "Save schedule" button that saved
                  // nothing, so it never reflected real state.
                  Icon(
                    destination.days.isEmpty
                        ? Icons.pending_outlined
                        : Icons.check_circle_rounded,
                    color: destination.days.isEmpty ? null : Colors.green,
                  ),
                ],
              ),
              if (destination.dates != null)
                Text(
                  '${_date(destination.dates!.start)} - ${_date(destination.dates!.end)}',
                ),
              const SizedBox(height: 16),
              if (destination.selectedHotel != null) ...[
                Text('Hotel', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  destination.selectedHotel!.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${Money.format(destination.selectedHotel!.nightlyRate, destination.currencyCode)}/night • '
                  '${Money.format(destination.selectedHotel!.totalCost, destination.currencyCode)} total',
                ),
                const Divider(height: 28),
              ],
              if (days.isEmpty)
                const Text('No schedule generated yet.')
              else
                for (var index = 0; index < days.length; index++) ...[
                  Text(
                    'Day ${dayOffset + index + 1}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  for (final place in days[index].places)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 17),
                          const SizedBox(width: 8),
                          PlacePhoto(
                            placeName: place.place.name,
                            photoUrls: place.place.photoUrls,
                            width: 52,
                            height: 52,
                            borderRadius: 12,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(place.place.name)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Destination subtotal',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    Money.format(
                      destination.estimatedTotalFor(travelers),
                      destination.currencyCode,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      destinationCards.add(const SizedBox(height: 16));
      dayOffset += days.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destinations.length == 1
                          ? destinations.first.destination
                          : '${destinations.first.destination} + ${destinations.length - 1} more',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${firstDate == null ? 'Dates not set' : '${_date(firstDate)} - ${_date(lastDate!)}'} • '
                      '${destinations.length} destinations • $travelers '
                      '${travelers == 1 ? 'traveler' : 'travelers'} • Budget '
                      '${Money.format(totalBudget, currencyCode)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ...destinationCards,
              _ReviewCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRIP TOTAL',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (hasMixedCurrencies)
                      _TextRow(
                        label: 'Currencies',
                        value:
                            '${currencies.join(', ')} — legs are priced in '
                            'different currencies, so they are not combined.',
                      )
                    else ...[
                      _TotalRow(
                        label: 'Hotels',
                        amount: hotelTotal,
                        currencyCode: currencyCode,
                      ),
                      _TotalRow(
                        label: 'Food',
                        amount: foodTotal,
                        currencyCode: currencyCode,
                      ),
                      _TotalRow(
                        label: 'Activities',
                        amount: activityTotal,
                        currencyCode: currencyCode,
                      ),
                      const _TextRow(
                        label: 'Transportation',
                        value: 'Not calculated yet',
                      ),
                      const Divider(height: 24),
                      _TotalRow(
                        label: 'Estimated total',
                        amount: estimatedTotal,
                        currencyCode: currencyCode,
                        strong: true,
                      ),
                      _TotalRow(
                        label: 'Budget',
                        amount: totalBudget,
                        currencyCode: currencyCode,
                      ),
                      _TotalRow(
                        label: 'Remaining',
                        amount: totalBudget - estimatedTotal,
                        currencyCode: currencyCode,
                        strong: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const ReviewWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    required this.currencyCode,
    this.strong = false,
  });
  final String label;
  final double amount;
  final String currencyCode;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: strong ? FontWeight.w900 : null),
          ),
        ),
        Text(
          Money.format(amount, currencyCode),
          style: TextStyle(fontWeight: strong ? FontWeight.w900 : null),
        ),
      ],
    ),
  );
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .78),
      ),
    ),
    child: child,
  );
}
