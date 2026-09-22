import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/models/place_evidence.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/service/osm_map_service.dart';
import 'package:travel/service/planner/destination_place_service.dart';
import 'package:travel/service/planner/place_quality_service.dart';
import 'package:travel/service/planner/place_scoring_service.dart';
import 'package:travel/service/planner/travel_planner_service.dart';

void main() {
  const quality = PlaceQualityService();
  test('mall types are excluded while markets remain eligible', () {
    for (final types in [ ['shopping_mall'], ['tourist_attraction', ' SHOPPING_MALL '] ]) {
      expect(quality.excluded(name: 'Fixture', types: types), isTrue);
    }
    expect(quality.excluded(name: 'Market', types: ['market']), isFalse);
  });
  final rejected = <String, Map<String, String>>{
    'mall raw tag': {'shop': 'mall'},
    'private garden': {'access': 'private'},
    'no entry': {'access': 'no'},
    'pedestrians prohibited': {'access': 'yes', 'foot': 'no'},
    'conditional private access': {
      'access': 'private',
      'access:conditional': 'yes @ (Sa)',
    },
    'disused venue': {'disused': 'yes'},
    'abandoned venue': {'abandoned': 'yes'},
    'demolished venue': {'demolished': 'yes'},
    'removed venue': {'removed': 'yes'},
    'construction site': {'construction': 'yes'},
    'closed museum': {'tourism': 'museum', 'disused:tourism': 'museum'},
    'old restaurant only': {'abandoned:amenity': 'restaurant'},
    'closed all day': {'opening_hours': 'off'},
    'closed explicitly': {'opening_hours': '24/7 closed'},
    'misclassified bank': {'tourism': 'attraction', 'amenity': 'bank'},
    'misclassified fuel station': {'amenity': 'fuel'},
    'misclassified shop': {'tourism': 'attraction', 'shop': 'electronics'},
  };
  for (final entry in rejected.entries) {
    test('excludes ${entry.key}', () {
      final evidence = PlaceEvidence.fromOsmTags(entry.value);
      expect(quality.evidenceExclusionReason(evidence), isNotNull);
      expect(
        quality.excluded(
          name: 'Fixture',
          types: ['tourist_attraction'],
          evidence: evidence,
        ),
        isTrue,
      );
    });
  }
  final allowed = <String, Map<String, String>>{
    'unknown information': {},
    'public park': {'access': 'yes'},
    'restaurant customers': {'amenity': 'restaurant', 'access': 'customers'},
    'pedestrian permission': {'access': 'private', 'foot': 'yes'},
    'no disused flag': {'disused': 'no', 'construction': 'no'},
    'weekly closing day': {'opening_hours': 'Mo off; Tu-Su 09:00-17:00'},
    'historic ruins': {'historic': 'ruins'},
    'former restaurant now museum': {
      'tourism': 'museum',
      'disused:amenity': 'restaurant',
    },
    'former pub now restaurant': {
      'amenity': 'restaurant',
      'disused:amenity': 'pub',
    },
    'bakery': {'shop': 'bakery'},
  };
  for (final entry in allowed.entries) {
    test('keeps ${entry.key}', () {
      expect(
        quality.excluded(
          name: 'Fixture',
          types: ['museum'],
          evidence: PlaceEvidence.fromOsmTags(entry.value),
        ),
        isFalse,
      );
    });
  }

  test(
    'area and expanded discovery exclude unsuitable places and hotels',
    () async {
      final requestedRadii = <int>[];
      final maps = OsmMapService(
        endpoint: 'https://example.test/osm',
        tokenProvider: () async => 'token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'suggest') {
            return http.Response(
              jsonEncode({
                'places': [record('city', 'locality', {})],
              }),
              200,
            );
          }
          requestedRadii.add(body['radius'] as int);
          final expanded = body['scope'] == 'activities';
          return http.Response(
            jsonEncode({
              'places': [
                record(expanded ? 'far-private' : 'private', 'park', {
                  'access': 'private',
                }),
                record(expanded ? 'far-closed' : 'closed', 'museum', {
                  'disused': 'yes',
                }),
                record(expanded ? 'far-bank' : 'bank', 'tourist_attraction', {
                  'amenity': 'bank',
                }),
                record(expanded ? 'far-good' : 'good', 'museum', {}),
                if (!expanded) ...[
                  record('closed-restaurant', 'restaurant', {
                    'opening_hours': 'off',
                  }),
                  record('closed-hotel', 'hotel', {'disused': 'yes'}),
                  record('good-hotel', 'hotel', {'access': 'customers'}),
                  for (var i = 0; i < 3; i++)
                    record('meal-$i', 'restaurant', {'access': 'customers'}),
                ],
              ],
            }),
            200,
          );
        }),
      );
      final pool = await DestinationPlaceService(mapService: maps)
          .loadForDestination(
            'Fixture city',
            priceContext: const PriceContext(
              currencyCode: 'USD',
              totalBudget: 1000,
              spendingStyle: 'Normal',
              days: 1,
              travelers: 1,
            ),
          );
      expect(requestedRadii, [5000, 10000, 15000]);
      expect(
        pool.places.map((p) => p.id),
        unorderedEquals([
          'osm:node:good',
          'osm:node:far-good',
          'osm:node:meal-0',
          'osm:node:meal-1',
          'osm:node:meal-2',
        ]),
      );
      expect(pool.hotels.map((p) => p.id), ['osm:node:good-hotel']);
      expect(pool.places.every((p) => p.reviewCount == 0), isTrue);
    },
  );

  test(
    'direct planner input cannot bypass exclusions or replace a missing meal with a closed venue',
    () {
      final good = travelPlace('good', 'museum', {});
        final candidates = [
        good,
        for (final entry in rejected.entries)
          travelPlace(entry.key, 'museum', entry.value),
        for (var i = 0; i < 3; i++) travelPlace('meal-$i', 'restaurant', {}),
      ];
      final planner = TravelPlannerService(
        placeScoringService: const PlaceScoringService(),
      );
      final trip = Trip(
        id: 'test',
        ownerId: 'test',
        destination: 'Fixture',
        budget: 1000,
        days: 1,
        status: 'draft',
      );
      final preference = Preference(
        id: 'test',
        ownerId: 'test',
        experienceType: ['History'],
        interests: ['History'],
        activityLevel: 'Moderate',
        spendingStyle: 'Normal',
      );
      final plan = planner.generatePlan(
        trip: trip,
        preference: preference,
        candidatePlaces: candidates,
        centerLatitude: 16,
        centerLongitude: 108,
      );
      expect(plan.validation.isValid, isTrue);
      expect(
        plan.rankedPlaces.map((p) => p.place.id),
        unorderedEquals([
          'osm:node:good',
          'osm:node:meal-0',
          'osm:node:meal-1',
          'osm:node:meal-2',
        ]),
      );
      expect(plan.days.single.places.map((p) => p.place.id), contains(good.id));
      final insufficient = planner.generatePlan(
        trip: trip,
        preference: preference,
        candidatePlaces: [
          good,
          travelPlace('meal-0', 'restaurant', {}),
          travelPlace('meal-1', 'restaurant', {}),
          travelPlace('closed-meal', 'restaurant', {'disused': 'yes'}),
        ],
        centerLatitude: 16,
        centerLongitude: 108,
      );
      expect(insufficient.validation.isValid, isFalse);
      expect(
        insufficient.rankedPlaces.any(
          (p) => p.place.id.endsWith('closed-meal'),
        ),
        isFalse,
      );
    },
  );
}

Map<String, Object> record(String id, String type, Map<String, String> tags) =>
    {
      'id': 'osm:node:$id',
      'name': 'Fixture $id',
      'latitude': 16,
      'longitude': 108,
      'types': [type],
      'evidence': {'osmTags': tags},
    };

TravelPlace travelPlace(String id, String category, Map<String, String> tags) =>
    TravelPlace.fromMap({
      ...record(id, category, tags),
      'category': category,
      'tags': [category],
      'estimatedCost': 5,
      'estimatedVisitMinutes': 60,
    });
