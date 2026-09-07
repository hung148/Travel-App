import 'dart:math';

import '../../core/utils/money.dart';
import '../../models/place_role.dart';
import '../../models/travel_place.dart';
import '../../models/hotel_stay.dart';
import '../../models/price_calibration.dart';
import '../budget_service.dart';
import '../map_service.dart';
import 'preference_normalizer.dart';
import 'price_calibration_service.dart';
import 'shopping_vetter.dart';
import 'travel_place_mapper.dart';

/// What the caller knows before any place has been fetched. Used to fall back
/// to budget-anchored pricing when a destination publishes no prices at all.
class PriceContext {
  final String currencyCode;
  final double totalBudget;
  final String spendingStyle;
  final int days;
  final int travelers;

  const PriceContext({
    required this.currencyCode,
    required this.totalBudget,
    required this.spendingStyle,
    required this.days,
    required this.travelers,
  });
}

class DestinationCandidates {
  final Coordinates center;
  final List<TravelPlace> places;
  final List<HotelStay> hotels;
  final PriceCalibration calibration;

  /// The currency Google quotes for this destination. Informational only - the
  /// plan is always priced in the currency the user chose.
  final String? detectedCurrencyCode;

  const DestinationCandidates({
    required this.center,
    required this.places,
    required this.hotels,
    required this.calibration,
    this.detectedCurrencyCode,
  });

  String get currencyCode => calibration.currencyCode;
}

class DestinationPlaceService {
  final MapService mapService;
  final TravelPlaceMapper mapper;
  final PriceCalibrationService calibrationService;
  final BudgetService budgetService;

  /// [shoppingVetter] is the only thing here that can read a place's NAME.
  /// Optional: with none supplied the type and review rules stand alone, which
  /// is what every test and the mock-data path rely on.
  final ShoppingVetter? shoppingVetter;

  const DestinationPlaceService({
    required this.mapService,
    this.mapper = const TravelPlaceMapper(),
    this.calibrationService = const PriceCalibrationService(),
    this.budgetService = const BudgetService(),
    this.shoppingVetter,
  });

  static const _candidateTypes = [
    'tourist_attraction',
    'museum',
    'park',
    'cafe',
    'restaurant',
    'bakery',
    'meal_takeaway',
  ];

  /// Shopping is found by Text Search, not Nearby Search.
  ///
  /// Nearby Search caps at 20 results ranked within the circle, which in a
  /// real city fills up with neighbourhood arcades before it ever reaches
  /// Vincom. Text Search ranks by prominence - the big ones first, which is
  /// the whole point.
  static const _shoppingQueries = ['shopping mall', 'market'];

  /// How many shopping stops enter the pool when the traveler did NOT ask for
  /// shopping. A couple of malls is plenty of texture for a normal trip.
  static const maxShoppingCandidates = 3;

  /// How many enter when shopping IS the stated preference. A city has only a
  /// handful of real malls and markets, so this is high enough to take all of
  /// them and let scoring decide.
  static const maxPreferredShoppingCandidates = 12;

  /// The absolute floor for calling something a shopping destination.
  ///
  /// Google's place types are filled in by the business owner, so a shophouse
  /// selling robot vacuums can and does register itself as `shopping_mall`
  /// with no other type to give it away. No type rule can catch that. Review
  /// count can: a real mall is in the thousands, a single shop is not.
  static const minShoppingReviewCount = 1000;

  /// A shopping stop also has to be in the same league as the busiest one in
  /// this destination. A 300-review shophouse is not a mall in a city whose
  /// real mall has 30,000 reviews, and this scales without a per-city table.
  static const shoppingReviewShareOfBusiest = 0.05;

  static const _accommodationTypes = {
    'lodging',
    'hotel',
    'hostel',
    'motel',
    'bed_and_breakfast',
    'guest_house',
    'resort_hotel',
    'extended_stay_hotel',
  };

  /// The last filter, and the only one that can read a name.
  ///
  /// Types and review counts cannot tell a mall from a shophouse that
  /// registered itself as one. This asks something that can. It fails open by
  /// contract: no vetter, or a vetter that could not reach its judge, and
  /// every candidate survives.
  Future<List<NearbyPlace>> _vetted(List<NearbyPlace> candidates) async {
    final vetter = shoppingVetter;
    if (vetter == null || candidates.isEmpty) return candidates;

    final approved = await vetter.approve([
      for (final place in candidates)
        ShoppingCandidate(
          placeId: place.placeId,
          name: place.name,
          address: place.address,
          primaryType: place.primaryType,
          types: place.types,
          reviewCount: place.userRatingsTotal,
        ),
    ]);
    return candidates
        .where((place) => approved.contains(place.placeId))
        .toList();
  }

  /// Biggest first. Review count is the closest thing Google gives us to a
  /// measure of how major a mall is - a landmark mall has tens of thousands of
  /// reviews, a neighbourhood one a few hundred.
  static List<NearbyPlace> _biggestShoppingFirst(
    Iterable<NearbyPlace> places,
  ) {
    return places.toList()
      ..sort((left, right) {
        final byReviews = right.userRatingsTotal.compareTo(
          left.userRatingsTotal,
        );
        if (byReviews != 0) return byReviews;
        return right.rating.compareTo(left.rating);
      });
  }

  /// [placeId] is the Google id of the suggestion the user picked. When it is
  /// present the center comes straight from Google instead of being guessed
  /// from the destination text, which is what keeps a city from resolving to
  /// its parent province.
  Future<DestinationCandidates> loadForDestination(
    String destination, {
    required PriceContext priceContext,
    String? placeId,
    int radiusMeters = 15000,
    Set<String> styleTags = const {},
  }) async {
    final center = await mapService.resolveDestinationCenter(
      destination,
      placeId: placeId,
    );
    return loadForArea(
      center: center,
      radiusMeters: radiusMeters,
      priceContext: priceContext,
      styleTags: styleTags,
    );
  }

  /// [styleTags] is the traveler's own preference wording. A trip that asked
  /// for shopping gets a much bigger share of the pool spent on malls and
  /// markets, which is what lets the plan actually come out shopping-heavy.
  Future<DestinationCandidates> loadForArea({
    required Coordinates center,
    required int radiusMeters,
    required PriceContext priceContext,
    Set<String> styleTags = const {},
  }) async {
    final searches = await Future.wait(
      _candidateTypes.map(
        (type) => mapService.getNearbyPlaces(
          latitude: center.latitude,
          longitude: center.longitude,
          radius: radiusMeters,
          type: type,
        ),
      ),
    );
    final hotelResults = await mapService.getNearbyPlaces(
      latitude: center.latitude,
      longitude: center.longitude,
      radius: radiusMeters,
      type: 'hotel',
    );
    final shoppingSearches = await Future.wait(
      _shoppingQueries.map(
        (query) => mapService.searchShoppingDestinations(
          latitude: center.latitude,
          longitude: center.longitude,
          radius: radiusMeters,
          query: query,
        ),
      ),
    );

    final uniquePlaces = <String, NearbyPlace>{};
    final shoppingCandidates = <String, NearbyPlace>{};

    for (final nearbyPlace in [
      ...searches.expand((places) => places),
      ...shoppingSearches.expand((places) => places),
    ]) {
      if (nearbyPlace.placeId.isEmpty || nearbyPlace.name.trim().isEmpty) {
        continue;
      }
      if (nearbyPlace.types.any(_accommodationTypes.contains)) {
        continue;
      }
      // A post office or a bank is an errand, not a stop - even when Google
      // returns it from a tourist_attraction search, which it does.
      if (isNonItineraryPlace(nearbyPlace.types)) continue;
      if (_distanceMeters(center, nearbyPlace) > radiusMeters) continue;

      // Retail is judged separately: a mall is a stop, a single shop is not.
      if (isRetailPlace(nearbyPlace.types)) {
        if (!nearbyPlace.isMajorShoppingDestination) continue;
        shoppingCandidates.putIfAbsent(
          nearbyPlace.placeId,
          () => nearbyPlace,
        );
        continue;
      }

      uniquePlaces.putIfAbsent(nearbyPlace.placeId, () => nearbyPlace);
    }

    const normalizer = PreferenceNormalizer();
    final shoppingQuota = wantsShopping(styleTags.expand(normalizer.expand))
        ? maxPreferredShoppingCandidates
        : maxShoppingCandidates;
    final rankedShopping = _biggestShoppingFirst(shoppingCandidates.values);
    final busiest = rankedShopping.isEmpty
        ? 0
        : rankedShopping.first.userRatingsTotal;
    final reviewFloor = max(
      minShoppingReviewCount,
      (busiest * shoppingReviewShareOfBusiest).round(),
    );
    final shoppingStops = rankedShopping
        .where((place) => place.userRatingsTotal >= reviewFloor)
        .take(shoppingQuota)
        .toList();

    for (final stop in await _vetted(shoppingStops)) {
      uniquePlaces.putIfAbsent(stop.placeId, () => stop);
    }

    // Hotels carry price data too, and there are usually plenty of them, so
    // including them makes both the currency detection and the calibration
    // noticeably more reliable.
    final pricingSample = <NearbyPlace>[
      ...uniquePlaces.values,
      ...hotelResults,
    ];

    // The user's chosen currency is authoritative. What Google publishes for
    // this area is recorded so the UI can explain itself, but it never changes
    // what the plan is priced in.
    final currency = Money.normalize(priceContext.currencyCode);
    final detectedCurrency = calibrationService.detectCurrency(pricingSample);

    final allocation = budgetService.allocate(
      totalBudget: priceContext.totalBudget < 0 ? 0 : priceContext.totalBudget,
      spendingStyle: priceContext.spendingStyle,
    );

    final calibration = calibrationService.calibrate(
      places: pricingSample,
      currencyCode: currency,
      // The budget is typed in this same currency, so it is always a valid
      // fallback anchor.
      foodBudget: allocation.food,
      days: priceContext.days,
      travelers: priceContext.travelers,
    );

    return DestinationCandidates(
      center: center,
      calibration: calibration,
      detectedCurrencyCode: detectedCurrency,
      places: uniquePlaces.values
          .map(
            (place) => mapper.fromNearbyPlace(place, calibration: calibration),
          )
          .toList(),
      hotels: hotelResults
          .where(
            (hotel) =>
                hotel.placeId.isNotEmpty &&
                hotel.name.trim().isNotEmpty &&
                _distanceMeters(center, hotel) <= radiusMeters,
          )
          .map((hotel) => _hotelStay(hotel, calibration))
          .toList()
        ..sort((left, right) => right.rating.compareTo(left.rating)),
    );
  }

  /// Nightly rates come from the same calibration as everything else, so a
  /// hotel in Da Lat is priced in dong and one in Zurich in francs without a
  /// single hardcoded figure.
  HotelStay _hotelStay(NearbyPlace hotel, PriceCalibration calibration) {
    final range = hotel.priceRange;
    final hasPublishedRate = range != null &&
        range.currencyCode.trim().toUpperCase() == calibration.currencyCode &&
        range.high > 0;

    final nightlyRate = hasPublishedRate
        ? (range.low + range.high) / 2
        : calibration.hotelNightBand(_hotelPriceLevel(hotel)).mid;

    return HotelStay(
      id: hotel.placeId,
      name: hotel.name,
      address: hotel.address,
      latitude: hotel.latitude,
      longitude: hotel.longitude,
      rating: hotel.rating,
      nightlyRate: nightlyRate,
      nights: 1,
      rooms: 1,
      nightlyRateEstimated: !hasPublishedRate,
    );
  }

  /// Google's price level when it publishes one, otherwise mid-range.
  ///
  /// Rating is deliberately NOT used as a price proxy. A star rating measures
  /// how much guests liked a hotel, not what it costs, and well-reviewed
  /// hotels are extremely common - mapping 4.7 stars onto "very expensive"
  /// (4.5x the meal anchor) is what turned a $700 accommodation allocation
  /// into a $1,320 estimate.
  int _hotelPriceLevel(NearbyPlace hotel) {
    final level = hotel.priceLevel;
    if (level != null && level > 0) return level;
    return 2;
  }

  double _distanceMeters(Coordinates center, NearbyPlace place) {
    return mapService.calculateDistanceKm(
          startLat: center.latitude,
          startLng: center.longitude,
          endLat: place.latitude,
          endLng: place.longitude,
        ) *
        1000;
  }
}
