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
    ];
  }
}
