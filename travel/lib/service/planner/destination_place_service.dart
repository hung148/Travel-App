import '../../core/utils/money.dart';
import '../../models/travel_place.dart';
import '../../models/hotel_stay.dart';
import '../../models/price_calibration.dart';
import '../budget_service.dart';
import '../map_service.dart';
import 'price_calibration_service.dart';
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

  const DestinationPlaceService({
    required this.mapService,
    this.mapper = const TravelPlaceMapper(),
    this.calibrationService = const PriceCalibrationService(),
    this.budgetService = const BudgetService(),
  });

  static const _candidateTypes = [
    'tourist_attraction',
    'museum',
    'park',
    'cafe',
    'restaurant',
    'bakery',
    'meal_takeaway',
    'shopping_mall',
  ];

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

  static bool _isInvalidRetailCandidate(NearbyPlace place) {
    final types = place.types.map((type) => type.toLowerCase().trim()).toSet();
    final isRetail =
        types.contains('store') || types.any((type) => type.endsWith('_store'));
    return isRetail && !place.isActualShoppingMall;
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
  }) async {
    final center = await mapService.resolveDestinationCenter(
      destination,
      placeId: placeId,
    );
    return loadForArea(
      center: center,
      radiusMeters: radiusMeters,
      priceContext: priceContext,
    );
  }

  Future<DestinationCandidates> loadForArea({
    required Coordinates center,
    required int radiusMeters,
    required PriceContext priceContext,
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

    final uniquePlaces = <String, NearbyPlace>{};
    for (final nearbyPlace in searches.expand((places) => places)) {
      if (nearbyPlace.placeId.isEmpty || nearbyPlace.name.trim().isEmpty) {
        continue;
      }
      if (nearbyPlace.types.any(_accommodationTypes.contains)) {
        continue;
      }
      if (_isInvalidRetailCandidate(nearbyPlace)) continue;
      if (_distanceMeters(center, nearbyPlace) > radiusMeters) continue;
      uniquePlaces.putIfAbsent(nearbyPlace.placeId, () => nearbyPlace);
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
