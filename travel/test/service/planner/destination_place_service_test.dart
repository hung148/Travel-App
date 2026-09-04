import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/map_service.dart';
import 'package:travel/service/planner/destination_place_service.dart';

void main() {
  test(
    'geocodes, deduplicates place types, and excludes accommodation',
    () async {
      final mapService = _FakeMapService();
      final service = DestinationPlaceService(mapService: mapService);

      final result = await service.loadForDestination('Test City');

      expect(result.center.latitude, 10);
      expect(result.center.longitude, 20);
      expect(mapService.requestedTypes, hasLength(9));
      expect(mapService.requestedTypes, contains('tourist_attraction'));
      expect(mapService.requestedTypes, contains('restaurant'));
      expect(
        mapService.requestedTypes,
        containsAll(['bakery', 'meal_takeaway', 'hotel']),
      );
      expect(result.places.map((place) => place.id), ['shared-place']);
      expect(
        result.places.map((place) => place.id),
        isNot(contains('sports-shop')),
      );
      expect(result.places.map((place) => place.id), isNot(contains('far-away')));
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
}

class _FakeMapService extends MapService {
  final List<String> requestedTypes = [];

  _FakeMapService() : super(apiKey: 'test-key');

  @override
  Future<Coordinates> geocodeAddress(String address) async {
    expect(address, 'Test City');
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
