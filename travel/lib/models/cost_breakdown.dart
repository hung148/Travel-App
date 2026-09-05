import '../core/utils/money.dart';
import 'cost_estimate.dart';
import 'planner_result.dart';
import 'travel_place.dart';

/// One priced stop, as it appears in the breakdown.
class CostBreakdownStop {
  final String name;
  final String category;
  final double amount;
  final bool isEstimated;
  final bool isPriced;

  /// Plain-language provenance, e.g. "estimated from Google's $$ rating".
  final String sourceDescription;

  const CostBreakdownStop({
    required this.name,
    required this.category,
    required this.amount,
    required this.isEstimated,
    required this.isPriced,
    required this.sourceDescription,
  });
}

class CostBreakdownDay {
  final int dayNumber;
  final List<CostBreakdownStop> meals;
  final List<CostBreakdownStop> activities;

  const CostBreakdownDay({
    required this.dayNumber,
    required this.meals,
    required this.activities,
  });

  double get mealTotal => meals.fold(0, (sum, stop) => sum + stop.amount);

  double get activityTotal =>
      activities.fold(0, (sum, stop) => sum + stop.amount);

  double get total => mealTotal + activityTotal;

  List<CostBreakdownStop> get stops => [...meals, ...activities];
}

/// Everything behind the single "total estimated trip expense" figure.
///
/// The itinerary shows one number; this is what you get when you ask where it
/// came from. Built once and read by both the breakdown sheet and the AI
/// assistant, so the explanation the user reads and the explanation the AI
/// gives can never drift apart.
class CostBreakdown {
  final String currencyCode;
  final PriceDisplayMode mode;
  final int travelers;
  final List<CostBreakdownDay> days;

  final double mealTotal;
  final double activityTotal;
  final double hotelTotal;
  final double total;
  final double budgetTotal;

  final String? hotelName;
  final double hotelNightlyRate;
  final int hotelNights;
  final int hotelRooms;
  final bool hotelRateEstimated;

  /// How the price ladder for this destination was produced.
  final String? calibrationNote;

  const CostBreakdown({
    required this.currencyCode,
    required this.mode,
    required this.travelers,
    required this.days,
    required this.mealTotal,
    required this.activityTotal,
    required this.hotelTotal,
    required this.total,
    required this.budgetTotal,
    required this.hotelName,
    required this.hotelNightlyRate,
    required this.hotelNights,
    required this.hotelRooms,
    required this.hotelRateEstimated,
    required this.calibrationNote,
  });

  factory CostBreakdown.from(PlannerResult result) {
    final multiplier = result.priceMultiplier;

    CostBreakdownStop stopFrom(TravelPlace place) {
      final CostEstimate cost = place.cost;
      return CostBreakdownStop(
        name: place.name,
        category: place.category.replaceAll('_', ' '),
        amount: cost.amountFor(multiplier),
        isEstimated: cost.isEstimated,
        isPriced: cost.source != CostSource.unknown,
        sourceDescription: cost.sourceDescription,
      );
    }

    final days = result.days
        .map(
          (day) => CostBreakdownDay(
            dayNumber: day.dayNumber,
            meals: day.places
                .where((item) => item.place.isDining)
                .map((item) => stopFrom(item.place))
                .toList(),
            activities: day.places
                .where((item) => !item.place.isDining)
                .map((item) => stopFrom(item.place))
                .toList(),
          ),
        )
        .toList();

    final hotel = result.hotel;
    // The hotel is already a whole-party cost, so under "per person" it is
    // divided rather than multiplied.
    final hotelShare = hotel == null
        ? 0.0
        : (result.priceDisplayMode == PriceDisplayMode.perPerson
              ? hotel.totalCost / result.partySize
              : hotel.totalCost);

    final mealTotal = days.fold<double>(0, (sum, day) => sum + day.mealTotal);
    final activityTotal = days.fold<double>(
      0,
      (sum, day) => sum + day.activityTotal,
    );

    return CostBreakdown(
      currencyCode: result.currencyCode,
      mode: result.priceDisplayMode,
      travelers: result.partySize,
      days: days,
      mealTotal: mealTotal,
      activityTotal: activityTotal,
      hotelTotal: hotelShare,
      total: mealTotal + activityTotal + hotelShare,
      budgetTotal: result.budgetAllocation.total,
      hotelName: hotel?.name,
      hotelNightlyRate: hotel?.nightlyRate ?? 0,
      hotelNights: hotel?.nights ?? 0,
      hotelRooms: hotel?.rooms ?? 0,
      hotelRateEstimated: hotel?.nightlyRateEstimated ?? false,
      calibrationNote: result.calibrationNote,
    );
  }

  List<CostBreakdownStop> get allStops =>
      days.expand((day) => day.stops).toList();

  int get stopCount => allStops.length;

  int get mealStopCount => days.fold(0, (n, day) => n + day.meals.length);

  int get activityStopCount =>
      days.fold(0, (n, day) => n + day.activities.length);

  int get estimatedStopCount =>
      allStops.where((stop) => stop.isEstimated).length;

  int get unpricedStopCount => allStops.where((stop) => !stop.isPriced).length;

  String get modeLabel => mode == PriceDisplayMode.perPerson
      ? 'per person'
      : '$travelers ${travelers == 1 ? 'traveler' : 'travelers'}';

  String money(double amount) => Money.format(amount, currencyCode);

  /// The budget is always the whole party's money, so it is only a fair
  /// comparison against the total when the total is a party figure too.
  bool get comparableToBudget => mode == PriceDisplayMode.total;

  double get remainingBudget => budgetTotal - total;

  /// The whole explanation as prose, for the AI assistant to reply with.
  ///
  /// Deliberately the same numbers the sheet shows: if these two ever
  /// disagree, the user is right to stop trusting both.
  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln('Total estimated trip expense: ${money(total)} ($modeLabel, '
          '$currencyCode).');

    if (comparableToBudget) {
      final remaining = remainingBudget;
      buffer.writeln(
        remaining >= 0
            ? 'Budget ${money(budgetTotal)} — ${money(remaining)} left over.'
            : 'Budget ${money(budgetTotal)} — over by ${money(-remaining)}.',
      );
    }

    buffer.writeln();
    buffer.writeln('It adds up like this:');
    if (hotelName != null) {
      buffer.writeln(
        '• Hotel ${money(hotelTotal)} — $hotelName at '
        '${money(hotelNightlyRate)} per room per night × $hotelNights '
        '${hotelNights == 1 ? 'night' : 'nights'} × $hotelRooms '
        '${hotelRooms == 1 ? 'room' : 'rooms'}'
        '${hotelRateEstimated ? ', rate estimated' : ''}.',
      );
    }
    buffer.writeln('• Meals ${money(mealTotal)} across $mealStopCount stops.');
    buffer.writeln(
      '• Activities ${money(activityTotal)} across $activityStopCount stops.',
    );

    for (final day in days) {
      if (day.stops.isEmpty) continue;
      buffer.writeln();
      buffer.writeln('Day ${day.dayNumber} — ${money(day.total)}');
      for (final stop in day.stops) {
        buffer.writeln(
          '   ${stop.name}: ${money(stop.amount)} (${stop.sourceDescription})',
        );
      }
    }

    buffer.writeln();
    if (estimatedStopCount > 0) {
      buffer.writeln(
        '$estimatedStopCount of $stopCount stops are estimates rather than '
        'published prices, so the real total will differ.',
      );
    }
    if (unpricedStopCount > 0) {
      buffer.writeln(
        '$unpricedStopCount ${unpricedStopCount == 1 ? 'stop has' : 'stops have'} '
        'no price data at all and count as zero here.',
      );
    }
    if (calibrationNote != null) buffer.writeln(calibrationNote);

    return buffer.toString().trimRight();
  }
}
