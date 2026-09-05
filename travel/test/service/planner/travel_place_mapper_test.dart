import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/price_calibration.dart';
import 'package:travel/service/map_service.dart';
import 'package:travel/service/planner/travel_place_mapper.dart';

void main() {
  const mapper = TravelPlaceMapper();
  const calibration = PriceCalibration(
    currencyCode: 'USD',
    levelBands: {2: PriceBand(25, 25)},
    source: PriceCalibrationSource.observedPrices,
    sampleSize: 1,
  );

  test('maps all Google nearby fields used by the planner', () {
    final result = mapper.fromNearbyPlace(
      NearbyPlace(
        placeId: 'google-id',
        name: 'Example Museum',
        address: '1 Example Street',
        latitude: 35.1,
        longitude: 139.1,
        rating: 4.7,
        userRatingsTotal: 1234,
        types: const ['museum', 'point_of_interest', 'establishment'],
        priceLevel: 2,
        photoUrl: 'https://example.com/place.jpg',
      ),
      calibration: calibration,
    );

    expect(result.id, 'google-id');
    expect(result.name, 'Example Museum');
    expect(result.category, 'museum');
    expect(result.tags, contains('point_of_interest'));
    expect(result.rating, 4.7);
    expect(result.reviewCount, 1234);
    expect(result.estimatedCost, 25);
    expect(result.photoUrl, 'https://example.com/place.jpg');
    expect(result.estimatedVisitMinutes, 120);
    expect(result.latitude, 35.1);
    expect(result.longitude, 139.1);
  });

  test('infers free park cost when Google has no price level', () {
    final result = mapper.fromNearbyPlace(
      NearbyPlace(
        placeId: 'park-id',
        name: 'Example Park',
        address: 'Park Road',
        latitude: 1,
        longitude: 2,
        rating: 4.2,
        userRatingsTotal: 50,
        types: const ['park', 'point_of_interest'],
      ),
      calibration: calibration,
    );

    expect(result.category, 'park');
    expect(result.estimatedCost, 0);
    expect(result.estimatedVisitMinutes, 90);
  });
}
