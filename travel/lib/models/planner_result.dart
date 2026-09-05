import '../core/utils/money.dart';
import 'budget_allocation.dart';
import 'cost_estimate.dart';
import 'planner_profile.dart';
import 'planner_validation.dart';
import 'score_place.dart';
import 'hotel_stay.dart';

class PlannerDay {
  final int dayNumber;
  final List<ScoredPlace> places;

  const PlannerDay({required this.dayNumber, required this.places});

  // --- Per-person totals --------------------------------------------------
  // These are what the planner and the validator compare, because every place
  // cost is per person. Never show one of these to a user directly: use the
  // ...For(travelers) methods below.

  double get estimatedCost =>
      places.fold(0, (total, item) => total + item.place.estimatedCost);

  double get estimatedFoodCost => places
      .where((item) => item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedCost);

  double get estimatedActivityCost => places
      .where((item) => !item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedCost);

  // --- Party totals -------------------------------------------------------
  // These are what the user is shown.

  double estimatedCostFor(int travelers) => places.fold(
        0,
        (total, item) => total + item.place.estimatedCostFor(travelers),
      );

  double estimatedFoodCostFor(int travelers) => places
      .where((item) => item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedCostFor(travelers));

  double estimatedActivityCostFor(int travelers) => places
      .where((item) => !item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedCostFor(travelers));

  /// True when at least one stop is priced from a guess rather than published
  /// data. Drives the "estimated" marker on the day total.
  bool get hasEstimatedCosts =>
      places.any((item) => item.place.cost.isEstimated);

  int get estimatedVisitMinutes => places.fold(
        0,
        (total, item) => total + item.place.estimatedVisitMinutes,
      );

  int get estimatedActivityMinutes => places
      .where((item) => !item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedVisitMinutes);

  int get diningCount => places.where((item) => item.place.isDining).length;

  int get activityCount => places.where((item) => !item.place.isDining).length;

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'places': places.map((item) => item.toMap()).toList(),
    };
  }

  factory PlannerDay.fromMap(Map<String, dynamic> data) {
    final placeList = data['places'] as List<dynamic>? ?? const [];

    return PlannerDay(
      dayNumber: (data['dayNumber'] as num?)?.toInt() ?? 0,
      places: placeList
          .whereType<Map>()
          .map((item) => ScoredPlace.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class PlannerResult {
  final BudgetAllocation budgetAllocation;
  final PlannerValidationResult validation;
  final PlannerProfile profile;
  final List<ScoredPlace> rankedPlaces;
  final List<PlannerDay> days;
  final HotelStay? hotel;
  final Map<String, int> startTimeOverrides;

  /// Party size every displayed total is computed for.
  final int travelers;

  /// Currency every amount in this result is denominated in. All amounts in a
  /// single result share one currency - nothing is ever converted.
  final String currencyCode;

  /// One line explaining where the price numbers came from, surfaced in the UI
  /// so the user is never guessing how much to trust them.
  final String? calibrationNote;

  /// Whether displayed amounts are per traveler or for the whole party. This
  /// is presentation only: the planner always works per person internally.
  final PriceDisplayMode priceDisplayMode;

  const PlannerResult({
    required this.budgetAllocation,
    required this.validation,
    required this.profile,
    required this.rankedPlaces,
    required this.days,
    this.hotel,
    this.startTimeOverrides = const {},
    this.travelers = 1,
    this.currencyCode = Money.defaultCurrencyCode,
    this.calibrationNote,
    this.priceDisplayMode = PriceDisplayMode.total,
  });

  PlannerResult copyWith({
    BudgetAllocation? budgetAllocation,
    PlannerValidationResult? validation,
    PlannerProfile? profile,
    List<ScoredPlace>? rankedPlaces,
    List<PlannerDay>? days,
    HotelStay? hotel,
    Map<String, int>? startTimeOverrides,
    int? travelers,
    String? currencyCode,
    String? calibrationNote,
    PriceDisplayMode? priceDisplayMode,
  }) =>
      PlannerResult(
        budgetAllocation: budgetAllocation ?? this.budgetAllocation,
        validation: validation ?? this.validation,
        profile: profile ?? this.profile,
        rankedPlaces: rankedPlaces ?? this.rankedPlaces,
        days: days ?? this.days,
        hotel: hotel ?? this.hotel,
        startTimeOverrides: startTimeOverrides ?? this.startTimeOverrides,
        travelers: travelers ?? this.travelers,
        currencyCode: currencyCode ?? this.currencyCode,
        calibrationNote: calibrationNote ?? this.calibrationNote,
        priceDisplayMode: priceDisplayMode ?? this.priceDisplayMode,
      );

  /// Party size, guaranteed to be at least one.
  int get partySize => travelers < 1 ? 1 : travelers;

  /// How many people a displayed amount covers under the current mode.
  /// Pass this to the ...For() methods so every visible figure agrees with the
  /// per-person / total toggle.
  int get priceMultiplier => priceDisplayMode.multiplierFor(partySize);

  /// Suffix for a heading, e.g. "for 2 travelers" or "per person".
  String get priceModeSuffix =>
      priceDisplayMode == PriceDisplayMode.perPerson
          ? 'per person'
          : '$partySize ${partySize == 1 ? 'traveler' : 'travelers'}';

  /// Food and activities under the current display mode.
  double get totalEstimatedCost => days.fold(
        0,
        (total, day) => total + day.estimatedCostFor(priceMultiplier),
      );

  /// Food and activities for the WHOLE party, whatever the display mode. Use
  /// this wherever the figure is compared against the budget, which is always
  /// the party's money.
  double get partyEstimatedCost =>
      days.fold(0, (total, day) => total + day.estimatedCostFor(partySize));

  double get totalEstimatedFoodCost => days.fold(
        0,
        (total, day) => total + day.estimatedFoodCostFor(priceMultiplier),
      );

  double get totalEstimatedActivityCost => days.fold(
        0,
        (total, day) => total + day.estimatedActivityCostFor(priceMultiplier),
      );

  /// The hotel is already a party total (nightlyRate * nights * rooms), so
  /// under "per person" it is divided rather than multiplied.
  double get totalEstimatedTripCost {
    final hotelTotal = hotel?.totalCost ?? 0;
    final hotelShare = priceDisplayMode == PriceDisplayMode.perPerson
        ? hotelTotal / partySize
        : hotelTotal;
    return totalEstimatedCost + hotelShare;
  }

  /// The whole party's trip cost, for budget comparisons.
  double get partyEstimatedTripCost =>
      partyEstimatedCost + (hotel?.totalCost ?? 0);

  bool get hasEstimatedCosts =>
      days.any((day) => day.hasEstimatedCosts) ||
      (hotel?.nightlyRateEstimated ?? false);

  /// Convenience for the UI, which formats a lot of amounts.
  String money(double amount) => Money.format(amount, currencyCode);
}
