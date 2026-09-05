import '../core/utils/money.dart';

/// What a cost number is measured against. Getting this wrong is how a
/// two-traveler trip ends up priced as a one-traveler trip.
enum CostBasis {
  /// One meal, one ticket, one head. Multiply by the traveler count.
  perPerson,

  /// Charged once for the whole party - a taxi, a parking fee, a group tour.
  perGroup,

  /// Charged per hotel room per night.
  perRoom,
}

/// Whether amounts are shown for one traveler or for the whole party.
/// The user picks this; it changes presentation only, never the planning math.
enum PriceDisplayMode {
  perPerson,
  total;

  /// How many people an amount should be multiplied by under this mode.
  int multiplierFor(int travelers) {
    if (this == PriceDisplayMode.perPerson) return 1;
    return travelers < 1 ? 1 : travelers;
  }

  String get label => this == PriceDisplayMode.perPerson
      ? 'Per person'
      : 'Total';
}

/// Where a cost number came from. This is what decides whether the UI is
/// allowed to print it as a currency amount.
enum CostSource {
  /// Google `priceRange` - a real band the place publishes.
  googlePriceRange,

  /// Google `priceLevel` - a $ / $$ / $$$ signal with no amount attached.
  /// The band is real, the amount attached to it is ours.
  googlePriceLevel,

  /// Reliably free: a public park, a lakeside promenade, a temple.
  knownFree,

  /// Our own per-category guess. Fine for packing a day against a budget,
  /// never fine to show the user as a price.
  categoryDefault,

  /// The user typed it.
  userProvided,

  /// Nothing known at all.
  unknown,
}

class CostEstimate {
  final double low;
  final double high;
  final String currencyCode;
  final CostBasis basis;
  final CostSource source;

  /// Google's 0-4 price level, kept even when an amount exists so the UI can
  /// always fall back to the band chip.
  final int? priceLevel;

  const CostEstimate({
    required this.low,
    required this.high,
    required this.currencyCode,
    required this.source,
    this.basis = CostBasis.perPerson,
    this.priceLevel,
  });

  const CostEstimate.unknown({
    this.currencyCode = Money.defaultCurrencyCode,
    this.basis = CostBasis.perPerson,
  })  : low = 0,
        high = 0,
        source = CostSource.unknown,
        priceLevel = null;

  const CostEstimate.free({
    this.currencyCode = Money.defaultCurrencyCode,
    this.basis = CostBasis.perPerson,
  })  : low = 0,
        high = 0,
        source = CostSource.knownFree,
        priceLevel = 0;

  /// True when this cost is a guess rather than published data. Drives the
  /// "estimated" marker on totals.
  bool get isEstimated =>
      source == CostSource.googlePriceLevel ||
      source == CostSource.categoryDefault ||
      source == CostSource.unknown;

  bool get isFree => source == CostSource.knownFree;

  bool get hasRange => high - low >= 1;

  /// The single scalar the planner packs days with. Always for ONE person for
  /// dining and attractions.
  double get planningAmount => (low + high) / 2;

  /// What the whole party pays for this stop.
  double amountFor(int travelers) {
    final party = travelers < 1 ? 1 : travelers;
    return basis == CostBasis.perPerson
        ? planningAmount * party
        : planningAmount;
  }

  /// The chip the itinerary shows instead of an invented figure.
  /// Null means nothing is known and the row should show no price at all.
  String? get bandLabel => switch (priceLevel) {
        0 => 'Free',
        1 => '\$',
        2 => '\$\$',
        3 => '\$\$\$',
        4 => '\$\$\$\$',
        _ => null,
      };

  /// What a stop row shows.
  ///
  /// Always an amount when we have one, because a plan the user cannot price
  /// is not much of a plan. Estimates are prefixed with "≈" so a guess is
  /// never mistaken for a published price - that marker, not the absence of a
  /// number, is what keeps this honest.
  ///
  /// Returns null only when nothing at all is known, and the row then shows no
  /// price rather than a fabricated one.
  String? label({
    required int travelers,
    PriceDisplayMode mode = PriceDisplayMode.perPerson,
  }) {
    if (isFree) return 'Free';
    if (source == CostSource.unknown || high <= 0) return null;

    // perGroup and perRoom costs are already whole-party amounts.
    final multiplier =
        basis == CostBasis.perPerson ? mode.multiplierFor(travelers) : 1;

    final text = hasRange
        ? Money.formatRange(low * multiplier, high * multiplier, currencyCode)
        : Money.format(planningAmount * multiplier, currencyCode);

    return isEstimated ? '≈$text' : text;
  }

  /// Plain-language provenance, for the cost breakdown and for the AI to
  /// quote back. This is the sentence that answers "why is it that much".
  String get sourceDescription => switch (source) {
        CostSource.googlePriceRange => 'published price range',
        CostSource.googlePriceLevel =>
          'estimated from Google\'s ${bandLabel ?? 'price level'} rating',
        CostSource.knownFree => 'free to enter',
        CostSource.categoryDefault => 'estimated from the place type',
        CostSource.userProvided => 'entered by you',
        CostSource.unknown => 'no price data available',
      };

  /// The per-person label, for places that show one price with no party
  /// context (a candidate list, a search result).
  String? get displayLabel => label(travelers: 1);

  CostEstimate copyWith({
    double? low,
    double? high,
    String? currencyCode,
    CostBasis? basis,
    CostSource? source,
    int? priceLevel,
  }) {
    return CostEstimate(
      low: low ?? this.low,
      high: high ?? this.high,
      currencyCode: currencyCode ?? this.currencyCode,
      basis: basis ?? this.basis,
      source: source ?? this.source,
      priceLevel: priceLevel ?? this.priceLevel,
    );
  }

  Map<String, dynamic> toMap() => {
        'low': low,
        'high': high,
        'currencyCode': currencyCode,
        'basis': basis.name,
        'source': source.name,
        'priceLevel': priceLevel,
      };

  factory CostEstimate.fromMap(Map<String, dynamic> data) {
    return CostEstimate(
      low: (data['low'] as num?)?.toDouble() ?? 0,
      high: (data['high'] as num?)?.toDouble() ?? 0,
      currencyCode: Money.normalize(data['currencyCode'] as String?),
      basis: CostBasis.values.firstWhere(
        (value) => value.name == data['basis'],
        orElse: () => CostBasis.perPerson,
      ),
      source: CostSource.values.firstWhere(
        (value) => value.name == data['source'],
        orElse: () => CostSource.unknown,
      ),
      priceLevel: (data['priceLevel'] as num?)?.toInt(),
    );
  }

  /// Trips saved before this change stored a bare `estimatedCost` double.
  /// Read them back honestly: that number was always a category guess.
  factory CostEstimate.legacy(
    double amount, {
    String currencyCode = Money.defaultCurrencyCode,
  }) {
    if (amount <= 0) return CostEstimate.free(currencyCode: currencyCode);
    return CostEstimate(
      low: amount,
      high: amount,
      currencyCode: Money.normalize(currencyCode),
      source: CostSource.categoryDefault,
    );
  }
}
