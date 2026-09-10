import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/trip/trip.dart';

import 'package:travel/service/map_service.dart';
import 'package:travel/service/planner/destination_place_service.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';
import 'package:travel/service/planner/daily_time_schedule_service.dart';

// Screenshot names reproduced with deliberately synthetic prices/review data.
// These are regression inputs, not live Google results or current menu prices.
void main() {
  test(
    'Da Nang pipeline rejects misclassified records and schedules highlights and upscale dinners',
    () async {
      final maps = _DaNangMaps();
      final pool = await DestinationPlaceService(mapService: maps)
          .loadForDestination(
            'Da Nang',
            priceContext: const PriceContext(
              currencyCode: 'USD',
              totalBudget: 5000,
              spendingStyle: 'Luxury',
              days: 2,
              travelers: 1,
            ),
          );
      expect(
        maps.queries,
        contains('top tourist attractions famous landmarks in Da Nang'),
      );
      expect(
        maps.queries,
        contains('best beaches scenic viewpoints in Da Nang'),
      );
      expect(maps.upscaleRequests, 1);
      final ids = pool.places.map((place) => place.id).toSet();
      expect(ids, isNot(contains('cemetery')));
      expect(ids, isNot(contains('pond')));
      expect(ids, isNot(contains('company')));
      expect(ids, isNot(contains('unreviewed-lake')));
      expect(ids, containsAll(['dragon', 'beach']));
      final result =
          TravelPlannerService(
            placeScoringService: const PlaceScoringService(),
          ).generatePlan(
            trip: Trip(
              id: 'trip',
              ownerId: 'user',
              destination: 'Da Nang',
              days: 2,
              budget: 5000,
              status: 'draft',
            ),
            preference: Preference(
              id: 'pref',
              ownerId: 'user',
              experienceType: const ['History'],
              activityLevel: 'Very Active',
              spendingStyle: 'Luxury',
              interests: const ['History'],
            ),
            candidatePlaces: pool.places,
            centerLatitude: 16.06,
            centerLongitude: 108.22,
          );
      expect(
        result.validation.isValid,
        isTrue,
        reason: result.validation.issues
            .map((issue) => issue.message)
            .join('\n'),
      );
      expect(
        result.days.expand((day) => day.places).map((item) => item.place.id),
        containsAll(['dragon', 'beach']),
      );
      for (final day in result.days) {
        final times = const DailyTimeScheduleService().schedule(day.places);
        final dinner = times.singleWhere((stop) => stop.roleLabel == 'Dinner');
        expect(dinner.scoredPlace.place.id, 'fine');
        expect(dinner.startMinutes, lessThanOrEqualTo(20 * 60));
        expect(
          times.singleWhere((stop) => stop.roleLabel == 'Lunch').startMinutes,
          lessThanOrEqualTo(14 * 60),
        );
      }
    },
  );

  test('partial discovery failure still provides an affordable plan', () async {
    final pool =
        await DestinationPlaceService(
          mapService: _DaNangMaps(failUpscale: true),
        ).loadForDestination(
          'Da Nang',
          priceContext: const PriceContext(
            currencyCode: 'USD',
            totalBudget: 5000,
            spendingStyle: 'Luxury',
            days: 1,
            travelers: 1,
          ),
        );
    final result =
        TravelPlannerService(
          placeScoringService: const PlaceScoringService(),
        ).generatePlan(
          trip: Trip(
            id: 'trip',
            ownerId: 'user',
            destination: 'Da Nang',
            days: 1,
            budget: 5000,
            status: 'draft',
          ),
          preference: Preference(
            id: 'pref',
            ownerId: 'user',
            experienceType: const ['Nature'],
            activityLevel: 'Moderate',
            spendingStyle: 'Luxury',
            interests: const ['Nature'],
          ),
          candidatePlaces: pool.places,
          centerLatitude: 16.06,
          centerLongitude: 108.22,
        );
    expect(result.validation.isValid, isTrue);
  });
}

class _DaNangMaps extends MapService {
  _DaNangMaps({this.failUpscale = false}) : super(apiKey: 'test-key');
  final bool failUpscale;
  final queries = <String>[];
  var upscaleRequests = 0;
  @override
  Future<Coordinates> resolveDestinationCenter(
    String destination, {
    String? placeId,
  }) async => Coordinates(latitude: 16.06, longitude: 108.22);
  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
  }) async {
    if (type == 'hotel') return [];
    return [
      record('cemetery', 'Nghĩa trang họ Trần, Phúc Kiến', 'museum'),
      record('pond', 'Ao cá Bàu Rèn', 'museum'),
      record('company', 'DNTN TÂN TÂN', 'museum'),
      record('unreviewed-lake', 'Bờ hồ', 'park', reviews: 2),
      record('pub', 'Quán Nhậu Hùng Vân', 'seafood_restaurant', priceLevel: 3),
      record('local', 'TÀ NÙNG QUÁN', 'restaurant', priceLevel: 2),
      record('breakfast', 'Bê Thui Mười Cầu Mống', 'restaurant', priceLevel: 1),
      for (var i = 0; i < 10; i++)
        record('museum-$i', 'Public museum $i', 'museum'),
    ];
  }

  @override
  Future<List<NearbyPlace>> searchShoppingDestinations({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
  }) async => [];
  @override
  Future<List<NearbyPlace>> searchPlacesInArea({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
    bool upscaleDiningOnly = false,
  }) async {
    queries.add(query);
    if (query.contains('fine dining')) {
      upscaleRequests++;
      if (failUpscale) throw StateError('Synthetic search outage');
      return [
        record(
          'fine',
          'Fine dining restaurant fixture',
          'fine_dining_restaurant',
          priceLevel: 3,
        ),
      ];
    }
    if (query.contains('landmarks')) {
      return [record('dragon', 'Cầu Rồng', 'tourist_attraction')];
    }
    if (query.contains('beaches')) {
      return [record('beach', 'Biển Mỹ Khê', 'beach')];
    }
    return [];
  }
}

NearbyPlace record(
  String id,
  String name,
  String type, {
  int? priceLevel,
  int reviews = 1000,
}) => NearbyPlace(
  placeId: id,
  name: name,
  address: 'Da Nang',
  latitude: 16.06,
  longitude: 108.22,
  rating: 4.6,
  userRatingsTotal: reviews,
  primaryType: type,
  types: [type],
  priceLevel: priceLevel,
  priceRange: priceLevel == null
      ? null
      : GooglePriceRange(
          low: priceLevel * 10.0,
          high: priceLevel * 10.0,
          currencyCode: 'USD',
        ),
);
