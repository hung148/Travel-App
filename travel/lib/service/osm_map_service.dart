import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/place_evidence.dart';
import 'map_service.dart';

/// OSM-backed place lookup. Google is never an automatic fallback.
class OsmMapService extends MapService {
  OsmMapService({
    http.Client? client,
    String? endpoint,
    Future<String?> Function()? tokenProvider,
  }) : _http = client ?? http.Client(),
       _endpoint = endpoint ?? AppConfig.osmPlacesUrl,
       _tokenProvider =
           tokenProvider ??
           (() =>
               FirebaseAuth.instance.currentUser?.getIdToken() ??
               Future.value(null)),
       super(apiKey: '');

  final http.Client _http;
  final String _endpoint;
  final Future<String?> Function() _tokenProvider;
  final _cache = <String, ({DateTime expires, List<NearbyPlace> places})>{};
  final _pending = <String, Future<List<NearbyPlace>>>{};
  static final _known = <String, NearbyPlace>{};
  static NearbyPlace? knownPlace(String id) => _known[id];
  bool googleFallbackAvailable = false;

  Future<List<PlaceSuggestion>> searchGoogle(String input) async {
    final places = await _fetch({
      'action': 'google',
      'query': input,
      'userRequested': true,
    });
    for (final place in places) {
      _known[place.placeId] = place;
    }
    return places
        .map(
          (p) => PlaceSuggestion(
            placeId: p.placeId,
            description: '${p.name}, ${p.address}',
            types: p.types,
          ),
        )
        .toList();
  }

  Future<List<NearbyPlace>> _lookup(Map<String, Object> request) async {
    final key = jsonEncode(request);
    final cached = _cache[key];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.places;
    }
    if (_pending[key] != null) return _pending[key]!;
    final future = _fetch(request);
    _pending[key] = future;
    try {
      final places = await future;
      if (_cache.length >= 32) _cache.remove(_cache.keys.first);
      _cache[key] = (
        expires: DateTime.now().add(const Duration(hours: 1)),
        places: places,
      );
      for (final place in places) {
        _known[place.placeId] = place;
      }
      return places;
    } finally {
      _pending.remove(key);
    }
  }

  Future<List<NearbyPlace>> _fetch(Map<String, Object> request) async {
    final token = await _tokenProvider();
    if (token == null) throw Exception('Sign in to search places.');
    final response = await _http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(request),
        )
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      // Preserve actionable backend errors without displaying arbitrary proxy bodies.
      const publicErrors = {
        'The production place provider is not configured yet.',
        'OpenStreetMap search is temporarily unavailable.',
        'Place search could not finish. Try a smaller area.',
        'Place search is busy. Try again shortly.',
        'Place discovery daily limit reached. Try again after 00:00 UTC.',
        'Destination search daily limit reached. Try again after 00:00 UTC.',
      };
      String? reason;
      try {
        final body = jsonDecode(response.body);
        if (body is Map && publicErrors.contains(body['error'])) {
          reason = body['error'] as String;
        }
      } on FormatException {
        // Non-JSON gateway errors use the fallback below.
      }
      throw Exception(
        reason ??
            'Place search unavailable (${response.statusCode}). Try again shortly or enter your plan manually.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (request['action'] != 'google') {
      googleFallbackAvailable = data['googleFallbackAvailable'] == true;
    }
    return (data['places'] as List).map((value) {
      final p = value as Map<String, dynamic>;
      return NearbyPlace(
        evidence: PlaceEvidence.fromMap(p['evidence']),
        placeId: p['id'] as String,
        name: p['name'] as String,
        address: p['address'] as String? ?? '',
        latitude: (p['latitude'] as num).toDouble(),
        longitude: (p['longitude'] as num).toDouble(),
        rating: 0,
        userRatingsTotal: 0,
        types: List<String>.from(p['types'] as List),
        primaryType: (p['types'] as List).isEmpty
            ? ''
            : p['types'][0] as String,
      );
    }).toList();
  }

  @override
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String input, {
    bool destinationCitiesOnly = false,
    bool tripDestinationsOnly = false,
  }) async {
    final places = await _lookup({'action': 'suggest', 'query': input.trim()});
    return places
        .map(
          (p) => PlaceSuggestion(
            placeId: p.placeId,
            description: p.address.isEmpty ? p.name : '${p.name}, ${p.address}',
            types: p.types,
          ),
        )
        .toList();
  }

  @override
  Future<PlaceDetails> getPlaceDetails(String placeId) async {
    var place = _known[placeId];
    if (place == null && placeId.startsWith('osm:')) {
      final results = await _lookup({'action': 'details', 'id': placeId});
      if (results.isNotEmpty) place = results.first;
    }
    if (place == null) {
      throw Exception(
        'Select an OpenStreetMap result or keep the saved location.',
      );
    }
    return PlaceDetails(
      placeId: place.placeId,
      name: place.name,
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
      rating: 0,
      types: place.types,
    );
  }

  @override
  Future<Coordinates> resolveDestinationCenter(
    String destination, {
    String? placeId,
  }) async {
    if (placeId != null &&
        (placeId.startsWith('osm:') || _known.containsKey(placeId))) {
      final p = await getPlaceDetails(placeId);
      return Coordinates(latitude: p.latitude, longitude: p.longitude);
    }
    final result = await searchDestinationByText(destination);
    if (result == null) {
      throw Exception(
        'No matching city found. Search its full local or English name, or choose an area on the map.',
      );
    }
    return result;
  }

  @override
  Future<Coordinates?> searchDestinationByText(String destination) async {
    final places = await _lookup({'action': 'suggest', 'query': destination});
    if (places.isEmpty) return null;
    if (places.length > 1) {
      throw Exception(
        'More than one city matches. Select a search result first.',
      );
    }
    return Coordinates(
      latitude: places.first.latitude,
      longitude: places.first.longitude,
    );
  }

  @override
  Future<Coordinates> geocodeAddress(
    String address, {
    bool preferAreaResult = false,
  }) async {
    if (!preferAreaResult) {
      throw Exception('Enter the precise coordinates for a custom address.');
    }
    return resolveDestinationCenter(address);
  }

  Future<List<NearbyPlace>> _area(
    double latitude,
    double longitude,
    int radius,
  ) => _lookup({
    'action': 'area',
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius.clamp(100, 20000),
  });

  Future<List<NearbyPlace>> discoverActivities(
    Coordinates center,
    int radius,
  ) => _lookup({
    'action': 'area',
    'scope': 'activities',
    'latitude': center.latitude,
    'longitude': center.longitude,
    'radius': radius.clamp(100, 20000),
  });

  @override
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
  }) async => (await _area(
    latitude,
    longitude,
    radius,
  )).where((p) => p.types.contains(type)).toList();

  @override
  Future<List<NearbyPlace>> searchPlacesInArea({
    required double latitude,
    required double longitude,
    required int radius,
    required String query,
    bool upscaleDiningOnly = false,
  }) async {
    final q = query.toLowerCase();
    final types = q.contains('hotel')
        ? {'hotel', 'hostel', 'guest_house', 'motel'}
        : q.contains('restaurant') || q.contains('dining')
        ? {'restaurant', 'cafe', 'meal_takeaway'}
        : q.contains('mall')
        ? {'shopping_mall', 'department_store'}
        : q.contains('market')
        ? {'market'}
        : q.contains('nightlife') || q.contains('bars')
        ? {'bar'}
        : {
            'tourist_attraction',
            'museum',
            'art_gallery',
            'historical_landmark',
            'park',
            'beach',
            'garden',
            'national_park',
            'zoo',
            'aquarium',
            'amusement_park',
          };
    return (await _area(
      latitude,
      longitude,
      radius,
    )).where((p) => p.types.any(types.contains)).toList();
  }

  Future<Map<String, dynamic>> _route(
    List<Coordinates> stops,
    String profile,
  ) async {
    final token = await _tokenProvider();
    if (token == null) throw Exception('Sign in to request directions.');
    final response = await _http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'action': 'route',
            'profile': profile,
            'coordinates': stops.map((p) => [p.longitude, p.latitude]).toList(),
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      String message = 'Routing is unavailable (${response.statusCode}).';
      try {
        final error = jsonDecode(response.body)['error'];
        if (error is String && error.length < 250) message = error;
      } catch (_) {
        /* Keep the HTTP status for non-JSON responses. */
      }
      throw Exception(message);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body)['route'] as Map);
  }

  @override
  Future<List<Coordinates>> getWalkingRoute(List<Coordinates> stops) async {
    final route = await _route(stops, 'foot-walking');
    return (route['coordinates'] as List)
        .map(
          (p) => Coordinates(
            latitude: (p[1] as num).toDouble(),
            longitude: (p[0] as num).toDouble(),
          ),
        )
        .toList();
  }

  @override
  Future<DrivingRouteEstimate> getDrivingRouteEstimate({
    required Coordinates origin,
    required Coordinates destination,
  }) async {
    final route = await _route([origin, destination], 'driving-car');
    return DrivingRouteEstimate(
      distanceKm: (route['distanceMeters'] as num) / 1000,
      durationHours: (route['durationSeconds'] as num) / 3600,
    );
  }
}
