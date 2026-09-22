import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/models/travel_place.dart';
import 'package:travel/service/osm_map_service.dart';
import 'package:travel/service/planner/travel_place_mapper.dart';
import 'package:travel/models/price_calibration.dart';

void main() {
  test(
    'OSM evidence survives discovery, mapping and saved-plan round trip',
    () async {
      const tags = {
        'opening_hours': 'Mo-Fr 09:00-17:00; PH off',
        'access': 'private',
        'access:conditional': 'yes @ (Sa-Su)',
        'contact:website': 'https://example.org/museum',
        'wikidata': 'Q123',
        'wikipedia': 'vi:Bảo tàng',
        'tourism': 'museum',
        'historic': 'monument',
        'heritage': '2',
        'disused': 'yes',
        'disused:tourism': 'museum',
      };
      final maps = OsmMapService(
        endpoint: 'https://example.test/osm',
        tokenProvider: () async => 'test-token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'osm:node:7001',
                  'name': 'Evidence fixture museum',
                  'latitude': 16,
                  'longitude': 108,
                  'types': ['museum'],
                  'evidence': {'osmTags': tags},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final records = await maps.getNearbyPlaces(
        latitude: 16,
        longitude: 108,
        radius: 1000,
        type: 'museum',
      );
      // Check retention below the eligibility filter: this private, disused
      // fixture must no longer enter the automatic destination candidate pool.
      final original = const TravelPlaceMapper().fromNearbyPlace(
        records.single,
        calibration: const PriceCalibration.empty(),
      );
      final restored = TravelPlace.fromMap(
        jsonDecode(jsonEncode(original.toMap())),
      );
      expect(restored.evidence.osmTags, tags);
      expect(restored.evidence.openingHours, tags['opening_hours']);
      expect(restored.evidence.access, 'private');
      expect(restored.evidence.website, tags['contact:website']);
      expect(restored.evidence.wikidata, 'Q123');
      expect(restored.evidence.wikipedia, tags['wikipedia']);
      expect(restored.rating, 0);
      expect(restored.reviewCount, 0);
      expect(
        () => restored.evidence.osmTags['access'] = 'yes',
        throwsUnsupportedError,
      );

      final legacyData = original.toMap()..remove('evidence');
      final legacy = TravelPlace.fromMap(legacyData);
      expect(legacy.evidence.osmTags, isEmpty);
      expect(legacy.evidence.openingHours, isNull);
      expect(legacy.evidence.access, isNull);
      expect(legacy.evidence.website, isNull);
      expect(legacy.id, original.id);
    },
  );

  test('malformed saved evidence does not prevent loading a plan', () {
    for (final evidence in [
      null,
      'invalid',
      {'osmTags': []},
      {
        'osmTags': {
          'access': false,
          'website': 123,
          'opening_hours': ' ',
          'historic': 'castle',
        },
      },
    ]) {
      final place = TravelPlace.fromMap({
        'id': 'osm:node:1',
        'evidence': evidence,
      });
      expect(place.evidence.access, isNull);
      expect(place.evidence.openingHours, isNull);
      expect(place.evidence.website, isNull);
    }
  });
}
