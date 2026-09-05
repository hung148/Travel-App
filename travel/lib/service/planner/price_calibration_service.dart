import '../../core/utils/money.dart';
import '../../models/price_calibration.dart';
import '../map_service.dart';

/// Turns whatever price data a destination happens to publish into a usable
/// price ladder, in that destination's own currency.
///
/// This exists so the app never needs a per-country price table or an exchange
/// rate. Da Lat calibrates in dong from Vietnamese prices, Zurich in francs
/// from Swiss prices, and a destination Google has barely priced falls back to
/// the user's own budget.
class PriceCalibrationService {
  const PriceCalibrationService();

  static const _mealsPerDay = 3;

  /// Fewer samples than this at one price level and the median is noise.
  static const _minSamplesPerLevel = 3;

  /// What currency this destination quotes prices in, read off the price data
  /// itself. No country-to-currency table, so it works anywhere Google has
  /// price coverage. Null when nothing published a price.
  String? detectCurrency(List<NearbyPlace> places) {
    final counts = <String, int>{};
    for (final place in places) {
      final range = place.priceRange;
      if (range == null) continue;
      if (!Money.isValidCode(range.currencyCode)) continue;
      final code = range.currencyCode.trim().toUpperCase();
      counts[code] = (counts[code] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    final ranked = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return ranked.first.key;
  }

  PriceCalibration calibrate({
    required List<NearbyPlace> places,
    required String currencyCode,
    required double foodBudget,
    required int days,
    required int travelers,
  }) {
    // The currency is the user's choice and is never overridden here.
    final currency = Money.normalize(currencyCode);
    final observedCurrency = detectCurrency(places);

    // Published prices are usable only when they are already in the currency
    // the user is planning in. We never convert.
    final observed = _observedAnchor(places, currency);
    if (observed != null) {
      return PriceCalibration.fromAnchor(
        currencyCode: currency,
        midRangeMeal: observed.band,
        source: PriceCalibrationSource.observedPrices,
        sampleSize: observed.sampleSize,
        observedCurrencyCode: observedCurrency,
      );
    }

    final budgetAnchor = _budgetAnchor(
      foodBudget: foodBudget,
      days: days,
      travelers: travelers,
    );
    if (budgetAnchor == null) {
      return PriceCalibration.empty(
        currencyCode: currency,
        observedCurrencyCode: observedCurrency,
      );
    }

    return PriceCalibration.fromAnchor(
      currencyCode: currency,
      midRangeMeal: budgetAnchor,
      source: PriceCalibrationSource.budgetDerived,
      sampleSize: 0,
      observedCurrencyCode: observedCurrency,
    );
  }

  /// Finds a level-2-equivalent band from whatever the destination published.
  ///
  /// Prefers actual level-2 places. Failing that it takes the best-sampled
  /// level and divides by that level's ratio to get back to the level-2 anchor,
  /// so an area where Google only priced the expensive places still calibrates
  /// correctly.
  _Anchor? _observedAnchor(List<NearbyPlace> places, String currency) {
    final byLevel = <int, List<PriceBand>>{};

    for (final place in places) {
      final range = place.priceRange;
      final level = place.priceLevel;
      if (range == null || level == null || level <= 0) continue;
      if (range.currencyCode.trim().toUpperCase() != currency) continue;
      if (range.high <= 0) continue;

      byLevel
          .putIfAbsent(level, () => <PriceBand>[])
          .add(PriceBand(range.low, range.high));
    }

    if (byLevel.isEmpty) return null;

    final wellSampled = byLevel.entries
        .where((entry) => entry.value.length >= _minSamplesPerLevel)
        .toList();

    MapEntry<int, List<PriceBand>> chosen;
    if (wellSampled.isEmpty) {
      final all = byLevel.entries.toList()
        ..sort((left, right) => right.value.length.compareTo(left.value.length));
      chosen = all.first;
    } else {
      wellSampled
          .sort((left, right) => right.value.length.compareTo(left.value.length));
      chosen = wellSampled.firstWhere(
        (entry) => entry.key == 2,
        orElse: () => wellSampled.first,
      );
    }

    final ratio = PriceCalibration.levelRatios[chosen.key] ?? 1.0;
    if (ratio <= 0) return null;

    final median = _medianBand(chosen.value);
    if (median.high <= 0) return null;

    return _Anchor(
      band: PriceBand(median.low / ratio, median.high / ratio),
      sampleSize: chosen.value.length,
    );
  }

  /// The user's own per-meal spend, in the user's own currency. Circular by
  /// design: with no market data, "affordable" can only mean "fits the budget".
  PriceBand? _budgetAnchor({
    required double foodBudget,
    required int days,
    required int travelers,
  }) {
    final safeDays = days < 1 ? 1 : days;
    final safeParty = travelers < 1 ? 1 : travelers;
    final perMeal = foodBudget / safeDays / safeParty / _mealsPerDay;
    if (!perMeal.isFinite || perMeal <= 0) return null;
    return PriceBand(perMeal * 0.7, perMeal * 1.3);
  }

  PriceBand _medianBand(List<PriceBand> bands) {
    final lows = bands.map((band) => band.low).toList()..sort();
    final highs = bands.map((band) => band.high).toList()..sort();
    return PriceBand(_median(lows), _median(highs));
  }

  double _median(List<double> sorted) {
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

class _Anchor {
  final PriceBand band;
  final int sampleSize;

  const _Anchor({required this.band, required this.sampleSize});
}
