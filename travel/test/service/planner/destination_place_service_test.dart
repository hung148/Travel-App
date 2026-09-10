import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/planner/destination_place_service.dart';
import 'package:travel/service/map_service.dart';
import 'package:travel/service/planner/shopping_vetter.dart';
import 'package:travel/service/currency_rate_service.dart';
import 'package:travel/models/cost_estimate.dart';

void main() {
  test(
    'converts published local prices and excludes hotel rates from meal calibration',
    () async {
      final rates = _Rates();
      addTearDown(rates.dispose);
      final pool =
          await DestinationPlaceService(
            mapService: _PricedMaps(),
            currencyRates: rates,
          ).loadForDestination(
            'Test City',
            priceContext: const PriceContext(
              currencyCode: 'USD',
              totalBudget: 1000,
              spendingStyle: 'Normal',
              days: 2,
              travelers: 1,
            ),
          );
      final meal = pool.places.firstWhere((place) => place.id == 'priced-meal');
      expect(meal.cost.low, 4);
      expect(meal.cost.high, 8);
      expect(meal.cost.currencyCode, 'USD');
      expect(meal.cost.source, CostSource.googlePriceRange);
      expect(pool.calibration.bandFor(2).mid, 6);
      expect(pool.detectedCurrencyCode, 'VND');
      expect(rates.calls, 1);
      final hotel = pool.hotels.firstWhere(
        (hotel) => hotel.id == 'priced-hotel',
      );
      expect(hotel.nightlyRate, closeTo(200, 0.001));
      expect(hotel.nightlyRateEstimated, isTrue);
    },
  );
  for (final style in ['Budget', 'Luxury']) {
    test('$style broadens dining and hotel searches', () async {
      final maps = _StyleMapService();
      final service = DestinationPlaceService(mapService: maps);
      final result = await service.loadForDestination(
        'Test City',
        priceContext: PriceContext(
          currencyCode: 'USD',
          totalBudget: 1000,
          spendingStyle: style,
          days: 3,
          travelers: 1,
        ),
      );
      expect(
        maps.queries,
        containsAll([
          'well reviewed local restaurants in Test City',
          'fine dining restaurants buffet in Test City',
          'well reviewed budget hotels in Test City',
          'luxury hotels in Test City',
        ]),
      );
      expect(
        result.places.map((place) => place.id),
        containsAll(['style-restaurant', 'hotel-buffet']),
      );
      expect(result.hotels.map((hotel) => hotel.id), contains('style-hotel'));
    });
  }
  test(
    'geocodes, deduplicates place types, and excludes accommodation',
    () async {
      final mapService = _FakeMapService();
      final service = DestinationPlaceService(mapService: mapService);
      const priceContext = PriceContext(
        currencyCode: 'USD',
        totalBudget: 1000,
        spendingStyle: 'Normal',
        days: 3,
        travelers: 1,
      );

      final result = await service.loadForDestination(
        'Test City',
        priceContext: priceContext,
      );

      expect(result.center.latitude, 10);
      expect(result.center.longitude, 20);
      expect(mapService.requestedTypes, hasLength(8));
      expect(mapService.requestedTypes, contains('tourist_attraction'));
      expect(mapService.requestedTypes, contains('restaurant'));
      expect(
        mapService.requestedTypes,
        containsAll(['bakery', 'meal_takeaway', 'hotel']),
      );
      // Shopping goes through Text Search, never Nearby Search.
      expect(mapService.requestedTypes, isNot(contains('shopping_mall')));
      expect(mapService.shoppingQueries, ['shopping mall', 'market']);
      expect(result.places.map((place) => place.id), ['shared-place']);
      expect(
        result.places.map((place) => place.id),
        isNot(contains('sports-shop')),
      );
      expect(
        result.places.map((place) => place.id),
        isNot(contains('far-away')),
      );
      expect(
        result.places.map((place) => place.id),
        isNot(contains('post-office')),
      );
      expect(
        result.hotels.map((hotel) => hotel.id),
        containsAll(['shared-place', 'hotel-place']),
      );
      expect(result.hotels.every((hotel) => hotel.nightlyRate > 0), isTrue);
      expect(
        result.hotels.every((hotel) => hotel.nightlyRateEstimated),
        isTrue,
      );
    },
  );

  test('forwards the picked placeId so the center is not guessed', () async {
    final mapService = _FakeMapService();
    final service = DestinationPlaceService(mapService: mapService);
    const priceContext = PriceContext(
      currencyCode: 'USD',
      totalBudget: 1000,
      spendingStyle: 'Normal',
      days: 3,
      travelers: 1,
    );

    await service.loadForDestination(
      'Test City',
      placeId: 'da-lat-place-id',
      priceContext: priceContext,
    );

    expect(mapService.resolvedPlaceId, 'da-lat-place-id');
  });

  test(
    'keeps only the biggest malls and drops shops that claim to be one',
    () async {
      final mapService = _FakeShoppingMapService();
      final service = DestinationPlaceService(mapService: mapService);
      const priceContext = PriceContext(
        currencyCode: 'USD',
        totalBudget: 1000,
        spendingStyle: 'Normal',
        days: 3,
        travelers: 1,
      );

      final result = await service.loadForArea(
        center: Coordinates(latitude: 10, longitude: 20),
        radiusMeters: 15000,
        priceContext: priceContext,
      );

      final ids = result.places.map((place) => place.id).toList();
      expect(ids, isNot(contains('shoe-shop')));
      expect(ids, isNot(contains('supermarket')));
      expect(ids, isNot(contains('vacuum-shop')));
      // The three busiest, mall or market alike.
      expect(ids, containsAll(['mall-huge', 'market-big', 'mall-big']));
      expect(ids, hasLength(DestinationPlaceService.maxShoppingCandidates));
      expect(ids, isNot(contains('mall-medium')));
      expect(ids, isNot(contains('mall-tiny')));
    },
  );

  test('a shopping preference gets a much bigger share of the pool', () async {
    final mapService = _FakeShoppingMapService();
    final service = DestinationPlaceService(mapService: mapService);
    const priceContext = PriceContext(
      currencyCode: 'USD',
      totalBudget: 1000,
      spendingStyle: 'Normal',
      days: 3,
      travelers: 1,
    );

    final result = await service.loadForArea(
      center: Coordinates(latitude: 10, longitude: 20),
      radiusMeters: 15000,
      priceContext: priceContext,
      styleTags: const {'Shopping'},
    );

    final ids = result.places.map((place) => place.id).toList();
    expect(
      ids,
      containsAll(['mall-huge', 'market-big', 'mall-big', 'mall-medium']),
    );
    expect(ids, isNot(contains('shoe-shop')));
    expect(ids, isNot(contains('supermarket')));
    // Below the review floor, preference or not. Only a review count
    // separates the vacuum shop from a mall - its types do not.
    expect(ids, isNot(contains('mall-tiny')));
    expect(ids, isNot(contains('vacuum-shop')));
  });

  test(
    'the vetter has the last word on a place the rules cannot judge',
    () async {
      final mapService = _FakeShoppingMapService();
      final vetter = _FakeVetter({'mall-big'});
      final service = DestinationPlaceService(
        mapService: mapService,
        shoppingVetter: vetter,
      );
      const priceContext = PriceContext(
        currencyCode: 'USD',
        totalBudget: 1000,
        spendingStyle: 'Normal',
        days: 3,
        travelers: 1,
      );

      final result = await service.loadForArea(
        center: Coordinates(latitude: 10, longitude: 20),
        radiusMeters: 15000,
        priceContext: priceContext,
        styleTags: const {'Shopping'},
      );

      final ids = result.places.map((place) => place.id).toList();
      expect(ids, isNot(contains('mall-big')));
      expect(ids, containsAll(['mall-huge', 'market-big']));

      // It gets the name and the review count - the two things a type rule
      // cannot see.
      final names = vetter.asked.map((candidate) => candidate.name).toList();
      expect(names, contains('mall-huge'));
      expect(
        vetter.asked.every((candidate) => candidate.reviewCount > 0),
        isTrue,
      );
      // Only shopping candidates are ever sent for judgement.
      expect(vetter.asked, hasLength(4));
    },
  );

  test('an unreachable vetter changes nothing', () async {
    final mapService = _FakeShoppingMapService();
    final service = DestinationPlaceService(
      mapService: mapService,
      shoppingVetter: _FailOpenVetter(),
    );
    const priceContext = PriceContext(
      currencyCode: 'USD',
      totalBudget: 1000,
      spendingStyle: 'Normal',
      days: 3,
      travelers: 1,
    );

    final result = await service.loadForArea(
      center: Coordinates(latitude: 10, longitude: 20),
      radiusMeters: 15000,
      priceContext: priceContext,
      styleTags: const {'Shopping'},
    );

    final ids = result.places.map((place) => place.id).toList();
    expect(
      ids,
      containsAll(['mall-huge', 'market-big', 'mall-big', 'mall-medium']),
    );
  });
}

/// Approves everything except the ids it was told to reject, and records what
/// it was asked about.
class _FakeVetter implements ShoppingVetter {
  _FakeVetter(this.rejected);

  final Set<String> rejected;
  final List<ShoppingCandidate> asked = [];

  @override
  Future<Set<String>> approve(List<ShoppingCandidate> candidates) async {
    asked.addAll(candidates);
    return candidates
        .map((candidate) => candidate.placeId)
        .where((placeId) => !rejected.contains(placeId))
        .toSet();
  }
}

/// Stands in for an unreachable vetting endpoint.
class _FailOpenVetter implements ShoppingVetter {
  @override
  Future<Set<String>> approve(List<ShoppingCandidate> candidates) async {
    return candidates.map((candidate) => candidate.placeId).toSet();
  }
}

class _StyleMapService extends _FakeMapService {
  final queries = <String>[];
  @override
  Future<List<NearbyPlace>> searchPlacesInArea({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
    bool upscaleDiningOnly = false,
  }) async {
    queries.add(query);
    final hotel = query.contains('hotels');
    return [
      if (query.contains('buffet'))
        NearbyPlace(
          placeId: 'hotel-buffet',
          name: 'Hotel buffet restaurant',
          address: 'City',
          latitude: latitude,
          longitude: longitude,
          rating: 4.6,
          userRatingsTotal: 300,
          primaryType: 'restaurant',
          types: const ['restaurant', 'lodging'],
          priceLevel: 3,
        ),
      NearbyPlace(
        placeId: hotel ? 'style-hotel' : 'style-restaurant',
        name: 'Style match',
        address: 'City',
        latitude: latitude,
        longitude: longitude,
        rating: 4.5,
        userRatingsTotal: 200,
        types: [hotel ? 'hotel' : 'restaurant'],
        priceLevel: 2,
      ),
    ];
  }
}

class _FakeMapService extends MapService {
  @override
  Future<List<NearbyPlace>> searchPlacesInArea({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
    bool upscaleDiningOnly = false,
  }) async => [];
  final List<String> requestedTypes = [];
  final List<String> shoppingQueries = [];

  @override
  Future<List<NearbyPlace>> searchShoppingDestinations({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
  }) async {
    shoppingQueries.add(query);
    return const [];
  }

  _FakeMapService() : super(apiKey: 'test-key');

  String? resolvedPlaceId;

  @override
  Future<Coordinates> resolveDestinationCenter(
    String destination, {
    String? placeId,
  }) async {
    expect(destination, 'Test City');
    resolvedPlaceId = placeId;
    return Coordinates(latitude: 10, longitude: 20);
  }

  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
  }) async {
    requestedTypes.add(type);
    return [
      NearbyPlace(
        placeId: 'shared-place',
        name: 'Shared Place',
        address: 'Address',
        latitude: latitude,
        longitude: longitude,
        rating: 4.5,
        userRatingsTotal: 100,
        types: [type, 'point_of_interest'],
      ),
      NearbyPlace(
        placeId: 'hotel-place',
        name: 'Hotel Returned as a Restaurant',
        address: 'Hotel Address',
        latitude: latitude,
        longitude: longitude,
        rating: 4.4,
        userRatingsTotal: 80,
        types: const ['hotel', 'lodging', 'restaurant'],
      ),
      if (type != 'hotel')
        NearbyPlace(
          placeId: 'sports-shop',
          name: 'Sportswear Shop',
          address: 'Retail Address',
          latitude: latitude,
          longitude: longitude,
          rating: 4.8,
          userRatingsTotal: 500,
          types: const ['sporting_goods_store', 'store'],
        ),
      // Google returns landmark post offices from a tourist_attraction
      // search. An errand is never an itinerary stop.
      if (type != 'hotel')
        NearbyPlace(
          placeId: 'post-office',
          name: 'Central Post Office',
          address: 'Civic Address',
          latitude: latitude,
          longitude: longitude,
          rating: 4.6,
          userRatingsTotal: 4000,
          types: const ['post_office', 'tourist_attraction'],
        ),
      if (type != 'hotel')
        NearbyPlace(
          placeId: 'far-away',
          name: 'Far Away Attraction',
          address: 'Outside the selected circle',
          latitude: 12,
          longitude: 22,
          rating: 5,
          userRatingsTotal: 1000,
          types: const ['tourist_attraction'],
        ),
    ];
  }
}

/// Returns four malls of very different sizes plus a shoe shop that carries
/// `shopping_mall` in its type list, which is what Google actually does.
class _FakeShoppingMapService extends MapService {
  @override
  Future<List<NearbyPlace>> searchPlacesInArea({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
    bool upscaleDiningOnly = false,
  }) async => [];
  _FakeShoppingMapService() : super(apiKey: 'test-key');

  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
  }) async {
    return const [];
  }

  @override
  Future<List<NearbyPlace>> searchShoppingDestinations({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
  }) async {
    // Every fixture comes back from the mall query; the market query returning
    // nothing keeps the fake from duplicating them.
    if (query != 'shopping mall') return const [];

    NearbyPlace mall(String id, int reviews) => NearbyPlace(
      placeId: id,
      name: id,
      address: 'Address',
      latitude: latitude,
      longitude: longitude,
      rating: 4.4,
      userRatingsTotal: reviews,
      types: const ['shopping_mall'],
      primaryType: 'shopping_mall',
    );

    return [
      mall('mall-tiny', 40), // below minShoppingReviewCount
      mall('mall-huge', 42000),
      mall('mall-medium', 3000),
      mall('mall-big', 9000),
      // The real-world miss: a shophouse selling robot vacuums that registered
      // itself as a shopping_mall, with no other type to give it away.
      NearbyPlace(
        placeId: 'vacuum-shop',
        name: 'Mi Việt Nam - 312 Điện Biên Phủ',
        address: 'Shophouse Address',
        latitude: latitude,
        longitude: longitude,
        rating: 4.9,
        userRatingsTotal: 300,
        types: const ['shopping_mall', 'point_of_interest'],
        primaryType: 'shopping_mall',
      ),
      NearbyPlace(
        placeId: 'market-big',
        name: 'Chợ Đà Lạt',
        address: 'Market Address',
        latitude: latitude,
        longitude: longitude,
        rating: 4.3,
        userRatingsTotal: 21000,
        types: const ['market', 'point_of_interest'],
        primaryType: 'market',
      ),
      NearbyPlace(
        placeId: 'supermarket',
        name: 'Big C',
        address: 'Supermarket Address',
        latitude: latitude,
        longitude: longitude,
        rating: 4.2,
        userRatingsTotal: 15000,
        types: const ['supermarket', 'market', 'store'],
        primaryType: 'supermarket',
      ),
      NearbyPlace(
        placeId: 'shoe-shop',
        name: 'Giày Việt',
        address: 'Retail Address',
        latitude: latitude,
        longitude: longitude,
        rating: 4.9,
        userRatingsTotal: 60000,
        types: const ['shoe_store', 'shopping_mall', 'store'],
        primaryType: 'shoe_store',
      ),
    ];
  }
}

class _Rates extends CurrencyRateService {
  int calls = 0;
  @override
  Future<ExchangeRate?> rate({required String from, required String to}) async {
    calls++;
    expect(from, 'VND');
    expect(to, 'USD');
    return ExchangeRate(
      base: from,
      quote: to,
      rate: 1 / 25000,
      fetchedAt: DateTime(2026),
    );
  }
}

class _PricedMaps extends _FakeMapService {
  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
  }) async => [
    if (type == 'restaurant' || type == 'hotel')
      NearbyPlace(
        placeId: type == 'hotel' ? 'priced-hotel' : 'priced-meal',
        name: 'Published price',
        address: 'City',
        latitude: latitude,
        longitude: longitude,
        rating: 4.6,
        userRatingsTotal: 500,
        types: [type],
        primaryType: type,
        priceLevel: 2,
        priceRange: GooglePriceRange(
          low: type == 'hotel' ? 5000000 : 100000,
          high: type == 'hotel' ? 5000000 : 200000,
          currencyCode: 'VND',
        ),
      ),
  ];
}
