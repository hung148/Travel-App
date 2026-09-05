import '../core/utils/money.dart';

class PriceBand {
  final double low;
  final double high;

  const PriceBand(this.low, this.high);

  const PriceBand.zero()
      : low = 0,
        high = 0;

  double get mid => (low + high) / 2;

  bool get isEmpty => high <= 0;

  PriceBand scaled(double factor) => PriceBand(low * factor, high * factor);
}

enum PriceCalibrationSource {
  /// Anchored on real prices Google published for this destination.
  observedPrices,

  /// No price data for this destination, so bands are anchored on what the
  /// user said they can spend. Relative positions still hold; the absolute
  /// amounts are the user's own numbers reflected back at them.
  budgetDerived,

  /// Neither published prices nor a usable budget. Everything is unpriced.
  none,
}

/// Maps Google's 0-4 price level onto amounts, in one currency, for one person.
///
/// Built per destination rather than hardcoded, which is what lets this work in
/// any country without an exchange rate or a per-currency price table.
class PriceCalibration {
  final String currencyCode;
  final Map<int, PriceBand> levelBands;
  final PriceCalibrationSource source;

  /// How many real priced places the anchor was computed from.
  final int sampleSize;

  /// The currency this destination actually publishes prices in, when it
  /// publishes any. Only used to explain why observed prices were not usable;
  /// it never overrides the currency the user picked.
  final String? observedCurrencyCode;

  /// The ratio ladder. Level 2 - a mid-range place - is the anchor, and every
  /// other level is a multiple of it. These ratios hold far better across
  /// countries than any absolute price, which is the whole point.
  static const levelRatios = <int, double>{
    0: 0.0,
    1: 0.45,
    2: 1.0,
    3: 2.2,
    4: 4.5,
  };

  /// A mid-range hotel room for one night costs roughly five mid-range meals.
  /// Also a ratio, also stable enough to travel between currencies.
  static const hotelNightsPerMeal = 5.0;

  const PriceCalibration({
    required this.currencyCode,
    required this.levelBands,
    required this.source,
    required this.sampleSize,
    this.observedCurrencyCode,
  });

  PriceCalibration.fromAnchor({
    required String currencyCode,
    required PriceBand midRangeMeal,
    required this.source,
    required this.sampleSize,
    this.observedCurrencyCode,
  })  : currencyCode = Money.normalize(currencyCode),
        levelBands = {
          for (final entry in levelRatios.entries)
            entry.key: midRangeMeal.scaled(entry.value),
        };

  const PriceCalibration.empty({
    this.currencyCode = Money.defaultCurrencyCode,
    this.observedCurrencyCode,
  })  : levelBands = const <int, PriceBand>{},
        source = PriceCalibrationSource.none,
        sampleSize = 0;

  PriceBand bandFor(int level) {
    final clamped = level < 0 ? 0 : (level > 4 ? 4 : level);
    return levelBands[clamped] ?? const PriceBand.zero();
  }

  /// One mid-range meal for one person - the anchor everything derives from.
  PriceBand get referenceMeal => bandFor(2);

  /// One hotel room for one night at the given price level.
  PriceBand hotelNightBand(int level) {
    final clamped = level < 0 ? 0 : (level > 4 ? 4 : level);
    final ratio = levelRatios[clamped] ?? 1.0;
    return referenceMeal.scaled(hotelNightsPerMeal * ratio);
  }

  bool get isUsable => !referenceMeal.isEmpty;

  /// True when this area publishes prices, but in a currency other than the
  /// one the user chose. We do not convert, so those prices go unused.
  bool get skippedForeignPrices =>
      observedCurrencyCode != null && observedCurrencyCode != currencyCode;

  /// One line for the UI, so the user can see where the numbers came from.
  String get explanation => switch (source) {
        PriceCalibrationSource.observedPrices =>
          'Prices calibrated from $sampleSize places with published price data '
              'in this area. Amounts marked ≈ are estimates.',
        PriceCalibrationSource.budgetDerived => skippedForeignPrices
            ? 'This area publishes prices in $observedCurrencyCode, but your '
                'plan is in $currencyCode. Amounts are estimated from your '
                'budget rather than converted, so all ≈ figures are '
                'approximate.'
            : 'No published prices for this area, so amounts are estimated '
                'from your budget. All ≈ figures are approximate.',
        PriceCalibrationSource.none =>
          'No price information available for this area.',
      };
}
