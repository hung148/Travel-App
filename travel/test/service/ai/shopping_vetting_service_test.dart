import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/service/ai/shopping_vetting_service.dart';
import 'package:travel/service/planner/shopping_vetter.dart';

const _vacuumShop = ShoppingCandidate(
  placeId: 'vacuum-shop',
  name: 'Mi Việt Nam - 312 Điện Biên Phủ',
  address: '312 Điện Biên Phủ, Đà Nẵng',
  primaryType: 'shopping_mall',
  types: ['shopping_mall', 'point_of_interest'],
  reviewCount: 300,
);

const _mall = ShoppingCandidate(
  placeId: 'vincom',
  name: 'Vincom Plaza Đà Nẵng',
  address: 'Ngô Quyền, Đà Nẵng',
  primaryType: 'shopping_mall',
  types: ['shopping_mall'],
  reviewCount: 30000,
);

ShoppingVettingService _service(MockClient client) {
  return ShoppingVettingService(
    endpoint: 'https://example.test/vetShoppingPlaces',
    client: client,
    idTokenProvider: () async => 'test-token',
  );
}

void main() {
  test('drops the places the server rejected and keeps the rest', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final places = body['places'] as List<dynamic>;
      expect(places, hasLength(2));
      expect(
        (places.first as Map<String, dynamic>)['name'],
        'Mi Việt Nam - 312 Điện Biên Phủ',
      );
      return http.Response(
        jsonEncode({
          'verdicts': {'vacuum-shop': false, 'vincom': true},
        }),
        200,
      );
    });

    final approved = await _service(client).approve([_vacuumShop, _mall]);

    expect(approved, {'vincom'});
  });

  test('keeps a place the server said nothing about', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'verdicts': {'vacuum-shop': false},
        }),
        200,
      ),
    );

    final approved = await _service(client).approve([_vacuumShop, _mall]);

    expect(approved, {'vincom'});
  });

  group('fails open, because an empty shopping plan is the worse bug', () {
    test('on a network failure', () async {
      final client = MockClient((request) async {
        throw http.ClientException('offline');
      });

      final approved = await _service(client).approve([_vacuumShop, _mall]);

      expect(approved, {'vacuum-shop', 'vincom'});
    });

    test('on a bad status', () async {
      final client = MockClient(
        (request) async => http.Response('nope', 502),
      );

      final approved = await _service(client).approve([_vacuumShop, _mall]);

      expect(approved, {'vacuum-shop', 'vincom'});
    });

    test('on an unreadable body', () async {
      final client = MockClient(
        (request) async => http.Response('not json', 200),
      );

      final approved = await _service(client).approve([_vacuumShop, _mall]);

      expect(approved, {'vacuum-shop', 'vincom'});
    });

    test('on a reply with no verdict map', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'ok': true}), 200),
      );

      final approved = await _service(client).approve([_vacuumShop, _mall]);

      expect(approved, {'vacuum-shop', 'vincom'});
    });

    test('when no endpoint is configured, without calling out', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service = ShoppingVettingService(endpoint: '  ', client: client);

      final approved = await service.approve([_vacuumShop, _mall]);

      expect(approved, {'vacuum-shop', 'vincom'});
      expect(called, isFalse);
    });

    test('when the id token cannot be fetched', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'verdicts': {'vacuum-shop': false},
          }),
          200,
        ),
      );
      final service = ShoppingVettingService(
        endpoint: 'https://example.test/vetShoppingPlaces',
        client: client,
        idTokenProvider: () async => throw Exception('signed out'),
      );

      final approved = await service.approve([_vacuumShop, _mall]);

      expect(approved, {'vacuum-shop', 'vincom'});
    });
  });
}
