import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// MapService
///
/// This service handles map-related logic for the travel app.
///
/// Main responsibilities:
/// - Search destination suggestions
/// - Resolve a destination to an exact map center
/// - Get place details
/// - Find nearby hotels / restaurants / attractions
/// - Calculate distance between 2 coordinates
///
/// Important:
/// This file uses Google Maps / Places APIs through HTTP requests.
///
/// You should store the API key safely.
/// Do NOT hardcode it directly in production.
///
/// Later, you can improve this by:
/// - moving the API key to .env
/// - using Cloud Functions / backend proxy
/// - adding route optimization logic
class MapService {
  final String apiKey;
  final http.Client _client;

  /// Constructor
  ///
  /// Example:
  /// final mapService = MapService(apiKey: 'YOUR_API_KEY');
  MapService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  /// ==============================
  /// Get autocomplete place suggestions
  /// ==============================
  ///
  /// Example input:
  /// "Paris"
  ///
  /// Returns a list of place suggestions from Google Places API
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String input, {
    bool destinationCitiesOnly = false,
    bool tripDestinationsOnly = false,
  }) async {
    if (input.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places:autocomplete',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'suggestions.placePrediction.placeId,'
            'suggestions.placePrediction.text,'
            'suggestions.placePrediction.types',
      },
      body: jsonEncode({
        'input': input.trim(),
        // Trip destinations are filtered locally using every type attached to
        // a prediction. Google's includedPrimaryTypes checks only one primary
        // type, which can hide valid cities such as Da Lat.
        if (!tripDestinationsOnly && destinationCitiesOnly)
          'includedPrimaryTypes': ['(cities)'],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch place suggestions.');
    }

    final data = jsonDecode(response.body);

    final suggestions = data['suggestions'] as List<dynamic>? ?? const [];

    final parsed = suggestions.map((item) {
      final prediction = item['placePrediction'] as Map<String, dynamic>? ?? {};
      return PlaceSuggestion(
        placeId: prediction['placeId'] ?? '',
        description: prediction['text']?['text'] ?? '',
        types: List<String>.from(prediction['types'] ?? const []),
      );
    }).toList();
    if (!tripDestinationsOnly) return parsed;

    final geographic = parsed
        .where((suggestion) => suggestion.isGeographicArea)
        .toList();

    // Google's autocomplete sometimes resolves Đà Lạt to its parent province
    // (Lâm Đồng) and omits the city itself. The fallback entry deliberately
    // carries no placeId: resolveDestinationCenter then falls through to
    // Places Text Search, which returns the city instead of the province.
    if (_isDaLatQuery(input)) {
      geographic.removeWhere(
        (suggestion) => _isLamDongWithoutDaLat(suggestion.description),
      );
      if (!geographic.any(
        (suggestion) => _isDaLatQuery(suggestion.description),
      )) {
        geographic.insert(
          0,
          const PlaceSuggestion(
            placeId: '',
            description: 'Đà Lạt, Lâm Đồng, Việt Nam',
            types: ['locality', 'political'],
          ),
        );
      }
    }
    return geographic;
  }

  /// ==============================
  /// Resolve a destination to its map center
  /// ==============================
  ///
  /// Every planning feature should go through this, so typing a destination
  /// lands on exactly the same point as picking it on the map.
  ///
  /// Resolution order:
  /// 1. The placeId of the suggestion the user actually picked. Exact.
  /// 2. Places Text Search, which resolves city names far better than the
  ///    Geocoding API (Đà Lạt returns the city, not Lâm Đồng province).
  /// 3. Geocoding, preferring a city-level result over a province one.
  Future<Coordinates> resolveDestinationCenter(
    String destination, {
    String? placeId,
  }) async {
    final id = placeId?.trim() ?? '';
    if (id.isNotEmpty) {
      try {
        final details = await getPlaceDetails(id);
        if (details.latitude != 0 || details.longitude != 0) {
          return Coordinates(
            latitude: details.latitude,
            longitude: details.longitude,
          );
        }
      } catch (_) {
        // A stale or synthetic id must never break planning. Fall through.
      }
    }

    try {
      final searched = await searchDestinationByText(destination);
      if (searched != null) return searched;
    } catch (_) {
      // Fall through to geocoding.
    }

    return geocodeAddress(destination, preferAreaResult: true);
  }

  /// Places Text Search lookup for a destination name.
  ///
  /// Returns the most city-like match, or null when Google has nothing usable.
  Future<Coordinates?> searchDestinationByText(String destination) async {
    final query = destination.trim();
    if (query.isEmpty) return null;

    final response = await _client.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchText'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.types',
      },
      body: jsonEncode({'textQuery': query, 'maxResultCount': 5}),
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = (data['places'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((place) => place['location'] != null)
        .toList();
    if (places.isEmpty) return null;

    final best = _bestAreaMatch(places) ?? places.first;
    final location = best['location'] as Map<String, dynamic>?;
    final latitude = (location?['latitude'] as num?)?.toDouble();
    final longitude = (location?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return Coordinates(latitude: latitude, longitude: longitude);
  }

  /// ==============================
  /// Get full place details by placeId
  /// ==============================
  ///
  /// Returns:
  /// - name
  /// - address
  /// - latitude
  /// - longitude
  /// - rating
  /// - types
  Future<PlaceDetails> getPlaceDetails(String placeId) async {
    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places/${Uri.encodeComponent(placeId)}',
    );
    final response = await _client.get(
      uri,
      headers: {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'id,displayName,formattedAddress,location,rating,types',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch place details.');
    }

    final data = jsonDecode(response.body);

    return PlaceDetails(
      placeId: data['id'] ?? '',
      name: data['displayName']?['text'] ?? '',
      address: data['formattedAddress'] ?? '',
      latitude: data['location']?['latitude']?.toDouble() ?? 0.0,
      longitude: data['location']?['longitude']?.toDouble() ?? 0.0,
      rating: (data['rating'] ?? 0).toDouble(),
      types: List<String>.from(data['types'] ?? []),
    );
  }

  /// ==============================
  /// Search nearby places
  /// ==============================
  ///
  /// Example use cases:
  /// - nearby restaurants
  /// - nearby hotels
  /// - nearby cafes
  /// - nearby tourist attractions
  ///
  /// Parameters:
  /// - latitude / longitude: center point
  /// - radius: search radius in meters
  /// - type: restaurant, lodging, cafe, tourist_attraction, etc.
  ///
  /// Returns a list of NearbyPlace
  Future<List<NearbyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
  }) async {
    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places:searchNearby',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,'
            'places.location,places.rating,places.userRatingCount,'
            'places.types,places.priceLevel,places.priceRange,places.photos',
      },
      body: jsonEncode({
        'includedTypes': [type],
        'maxResultCount': 20,
        'locationRestriction': {
          'circle': {
            'center': {'latitude': latitude, 'longitude': longitude},
            'radius': radius.toDouble(),
          },
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch nearby places.');
    }

    final data = jsonDecode(response.body);

    final results = data['places'] as List<dynamic>? ?? const [];

    final places = results.map((item) {
      return NearbyPlace(
        placeId: item['id'] ?? '',
        name: item['displayName']?['text'] ?? '',
        address: item['formattedAddress'] ?? '',
        latitude: item['location']?['latitude']?.toDouble() ?? 0.0,
        longitude: item['location']?['longitude']?.toDouble() ?? 0.0,
        rating: (item['rating'] ?? 0).toDouble(),
        userRatingsTotal: item['userRatingCount'] ?? 0,
        types: List<String>.from(item['types'] ?? []),
        priceLevel: _priceLevelFromGoogle(item['priceLevel']),
        priceRange: _priceRangeFromGoogle(item['priceRange']),
        photoUrls: _photoUrls(item['photos']),
      );
    }).toList();

    // The nearby endpoint can occasionally return related retail businesses
    // for a mall search. Never allow those results to enter the candidate pool.
    if (type == 'shopping_mall') {
      return places.where((place) => place.isActualShoppingMall).toList();
    }
    return places;
  }

  static bool _isDaLatQuery(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('đ', 'd')
        .replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return RegExp(r'(^| )da ?lat($| )').hasMatch(normalized);
  }

  static bool _isLamDongWithoutDaLat(String value) {
    final lower = value.toLowerCase();
    return (lower.contains('lâm đồng') || lower.contains('lam dong')) &&
        !_isDaLatQuery(value);
  }

  /// Most specific geographic types first, so a city always beats the
  /// province that contains it.
  static const _areaTypeRanking = <String>[
    'locality',
    'postal_town',
    'sublocality',
    'sublocality_level_1',
    'administrative_area_level_3',
    'administrative_area_level_2',
    'administrative_area_level_1',
    'colloquial_area',
    'country',
  ];

  static int _areaRank(Set<String> types) {
    for (var index = 0; index < _areaTypeRanking.length; index++) {
      if (types.contains(_areaTypeRanking[index])) return index;
    }
    return _areaTypeRanking.length;
  }

  static Set<String> _typesOf(Map<String, dynamic> value) {
    return (value['types'] as List<dynamic>? ?? const [])
        .map((type) => type.toString().toLowerCase().trim())
        .toSet();
  }

  /// Picks the most city-like entry. Ties keep Google's original order.
  static Map<String, dynamic>? _bestAreaMatch(
    Iterable<Map<String, dynamic>> candidates,
  ) {
    Map<String, dynamic>? best;
    var bestRank = _areaTypeRanking.length + 1;
    for (final candidate in candidates) {
      final rank = _areaRank(_typesOf(candidate));
      if (best == null || rank < bestRank) {
        best = candidate;
        bestRank = rank;
      }
    }
    return best;
  }

  /// ==============================
  /// Geocode a text address into coordinates
  /// ==============================
  ///
  /// Example:
  /// "Ho Chi Minh City"
  ///
  /// Returns coordinates of the searched location.
  ///
  /// [preferAreaResult] is for destination lookups: it picks the city-level
  /// result instead of Google's first result, which is often the province.
  /// Leave it false for street addresses such as a hotel.
  Future<Coordinates> geocodeAddress(
    String address, {
    bool preferAreaResult = false,
  }) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(address.trim())}'
      '&key=$apiKey',
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to geocode address.');
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 'OK') {
      throw Exception(data['error_message'] ?? 'Geocoding error.');
    }

    final results = data['results'] as List<dynamic>? ?? const [];
    if (results.isEmpty) {
      throw Exception('Geocoding returned no results.');
    }

    final result = preferAreaResult
        ? (_bestAreaMatch(results.whereType<Map<String, dynamic>>()) ??
              results.first)
        : results.first;
    final location = result['geometry']['location'];

    return Coordinates(
      latitude: location['lat'].toDouble(),
      longitude: location['lng'].toDouble(),
    );
  }

  /// Returns a street-following walking route through the supplied stops.
  /// Google returns an encoded polyline, which is decoded into map coordinates.
  Future<List<Coordinates>> getWalkingRoute(List<Coordinates> stops) async {
    if (stops.length < 2) return List<Coordinates>.of(stops);

    final response = await _client.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
      },
      body: jsonEncode({
        'origin': _routeWaypoint(stops.first),
        'destination': _routeWaypoint(stops.last),
        if (stops.length > 2)
          'intermediates': stops
              .sublist(1, stops.length - 1)
              .map(_routeWaypoint)
              .toList(),
        'travelMode': 'WALK',
        'polylineQuality': 'HIGH_QUALITY',
        'polylineEncoding': 'ENCODED_POLYLINE',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to calculate walking route.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>? ?? const [];
    final encoded = routes.isEmpty
        ? null
        : routes.first['polyline']?['encodedPolyline'] as String?;
    if (encoded == null || encoded.isEmpty) {
      throw Exception('Google Routes returned no walking route.');
    }
    return _decodePolyline(encoded);
  }

  Future<DrivingRouteEstimate> getDrivingRouteEstimate({
    required Coordinates origin,
    required Coordinates destination,
  }) async {
    final response = await _client.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration',
      },
      body: jsonEncode({
        'origin': _routeWaypoint(origin),
        'destination': _routeWaypoint(destination),
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_UNAWARE',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to calculate driving time.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) throw Exception('Google Routes returned no route.');
    final route = routes.first as Map<String, dynamic>;
    final durationText = route['duration'] as String? ?? '0s';
    return DrivingRouteEstimate(
      distanceKm: ((route['distanceMeters'] as num?)?.toDouble() ?? 0) / 1000,
      durationHours: _durationSeconds(durationText) / 3600,
    );
  }

  double _durationSeconds(String value) {
    return double.tryParse(value.replaceFirst(RegExp(r's$'), '')) ?? 0;
  }

  Map<String, dynamic> _routeWaypoint(Coordinates coordinates) {
    return {
      'location': {
        'latLng': {
          'latitude': coordinates.latitude,
          'longitude': coordinates.longitude,
        },
      },
    };
  }

  List<Coordinates> _decodePolyline(String encoded) {
    final points = <Coordinates>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      final latitudeResult = _decodePolylineValue(encoded, index);
      index = latitudeResult.nextIndex;
      latitude += latitudeResult.delta;

      final longitudeResult = _decodePolylineValue(encoded, index);
      index = longitudeResult.nextIndex;
      longitude += longitudeResult.delta;

      points.add(
        Coordinates(latitude: latitude / 1e5, longitude: longitude / 1e5),
      );
    }
    return points;
  }

  ({int delta, int nextIndex}) _decodePolylineValue(
    String encoded,
    int startIndex,
  ) {
    var result = 0;
    var shift = 0;
    var index = startIndex;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    final delta = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    return (delta: delta, nextIndex: index);
  }

  /// ==============================
  /// Calculate straight-line distance
  /// ==============================
  ///
  /// Uses the Haversine formula
  ///
  /// Returns distance in kilometers
  double calculateDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const double earthRadiusKm = 6371;

    final double dLat = _degreesToRadians(endLat - startLat);
    final double dLng = _degreesToRadians(endLng - startLng);

    final double a =
        pow(sin(dLat / 2), 2).toDouble() +
        cos(_degreesToRadians(startLat)) *
            cos(_degreesToRadians(endLat)) *
            pow(sin(dLng / 2), 2).toDouble();

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// ==============================
  /// Filter places by minimum rating
  /// ==============================
  ///
  /// Example:
  /// only keep places rated 4.0 and above
  List<NearbyPlace> filterByMinRating(
    List<NearbyPlace> places, {
    double minRating = 4.0,
  }) {
    return places.where((place) => place.rating >= minRating).toList();
  }

  /// ==============================
  /// Sort places by rating descending
  /// ==============================
  List<NearbyPlace> sortByRating(List<NearbyPlace> places) {
    final sorted = List<NearbyPlace>.from(places);
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  /// ==============================
  /// Sort places by distance from a center point
  /// ==============================
  List<NearbyPlace> sortByDistance({
    required List<NearbyPlace> places,
    required double userLat,
    required double userLng,
  }) {
    final sorted = List<NearbyPlace>.from(places);

    sorted.sort((a, b) {
      final distanceA = calculateDistanceKm(
        startLat: userLat,
        startLng: userLng,
        endLat: a.latitude,
        endLng: a.longitude,
      );

      final distanceB = calculateDistanceKm(
        startLat: userLat,
        startLng: userLng,
        endLat: b.latitude,
        endLng: b.longitude,
      );

      return distanceA.compareTo(distanceB);
    });

    return sorted;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Google returns Money as { currencyCode, units, nanos }.
  /// $1.75 arrives as units: 1, nanos: 750000000.
  double? _moneyAmount(Object? value) {
    if (value is! Map) return null;
    final rawUnits = value['units'];
    final units = rawUnits is num
        ? rawUnits.toDouble()
        : double.tryParse(rawUnits?.toString() ?? '');
    final nanos = (value['nanos'] as num?)?.toDouble() ?? 0;
    if (units == null && nanos == 0) return null;
    return (units ?? 0) + nanos / 1000000000;
  }

  /// The published price band for a place, in whatever currency the country
  /// uses. Never converted - the planner keeps one currency per trip.
  GooglePriceRange? _priceRangeFromGoogle(Object? value) {
    if (value is! Map) return null;
    final start = _moneyAmount(value['startPrice']);
    final end = _moneyAmount(value['endPrice']);
    if (start == null && end == null) return null;

    final startCurrency = value['startPrice'] is Map
        ? (value['startPrice'] as Map)['currencyCode'] as String?
        : null;
    final endCurrency = value['endPrice'] is Map
        ? (value['endPrice'] as Map)['currencyCode'] as String?
        : null;
    final currency = startCurrency ?? endCurrency;
    if (currency == null || currency.trim().isEmpty) return null;

    final low = start ?? end!;
    final high = end ?? start!;
    return GooglePriceRange(
      low: low <= high ? low : high,
      high: high >= low ? high : low,
      currencyCode: currency.trim().toUpperCase(),
    );
  }

  int? _priceLevelFromGoogle(Object? value) {
    return switch (value) {
      'PRICE_LEVEL_FREE' => 0,
      'PRICE_LEVEL_INEXPENSIVE' => 1,
      'PRICE_LEVEL_MODERATE' => 2,
      'PRICE_LEVEL_EXPENSIVE' => 3,
      'PRICE_LEVEL_VERY_EXPENSIVE' => 4,
      _ => null,
    };
  }

  /// Every photo Google returns for a place, capped.
  ///
  /// Each of these URLs is a separate billed Places Photo request when it is
  /// actually rendered, so the cap keeps a saved trip - and the bill - from
  /// growing with however many photos a popular place happens to have.
  static const maxPhotosPerPlace = 5;

  List<String> _photoUrls(Object? value) {
    final photos = value as List<dynamic>? ?? const [];
    final urls = <String>[];

    for (final photo in photos) {
      if (urls.length >= maxPhotosPerPlace) break;
      if (photo is! Map) continue;
      final name = photo['name'] as String?;
      if (name == null || name.isEmpty) continue;
      urls.add(
        Uri.https('places.googleapis.com', '/v1/$name/media', {
          'maxWidthPx': '1200',
          'maxHeightPx': '900',
          'key': apiKey,
        }).toString(),
      );
    }

    return urls;
  }
}

/// ==============================
/// Helper model: place suggestion
/// ==============================
class PlaceSuggestion {
  final String placeId;
  final String description;
  final List<String> types;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    this.types = const [],
  });

  bool get isGeographicArea => types.any(_geographicTypes.contains);

  static const _geographicTypes = {
    'locality',
    'country',
    'political',
    'colloquial_area',
    'sublocality',
    'sublocality_level_1',
    'sublocality_level_2',
    'sublocality_level_3',
    'sublocality_level_4',
    'sublocality_level_5',
    'administrative_area_level_1',
    'administrative_area_level_2',
    'administrative_area_level_3',
    'administrative_area_level_4',
    'administrative_area_level_5',
    'administrative_area_level_6',
    'administrative_area_level_7',
  };

  @override
  String toString() {
    return 'PlaceSuggestion(placeId: $placeId, description: $description)';
  }
}

/// ==============================
/// Helper model: place details
/// ==============================
class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final List<String> types;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.types,
  });

  @override
  String toString() {
    return 'PlaceDetails(placeId: $placeId, name: $name, address: $address, latitude: $latitude, longitude: $longitude, rating: $rating, types: $types)';
  }
}

/// ==============================
/// Helper model: nearby place
/// ==============================
/// A price band Google publishes for a place, in the place's own currency.
/// Amounts are never converted: a trip is planned in exactly one currency.
class GooglePriceRange {
  final double low;
  final double high;
  final String currencyCode;

  const GooglePriceRange({
    required this.low,
    required this.high,
    required this.currencyCode,
  });

  @override
  String toString() =>
      'GooglePriceRange($low-$high $currencyCode)';
}

class NearbyPlace {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int userRatingsTotal;
  final List<String> types;
  final int? priceLevel;

  /// Published price band, when Google has one for this place.
  final GooglePriceRange? priceRange;
  final List<String> photoUrls;

  /// The first photo, for callers that only show one.
  String? get photoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  NearbyPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingsTotal,
    required this.types,
    this.priceLevel,
    this.priceRange,
    this.photoUrls = const [],
  });

  bool get isActualShoppingMall {
    final normalizedTypes = types
        .map((type) => type.toLowerCase().trim())
        .toSet();
    return normalizedTypes.contains('shopping_mall');
  }

  @override
  String toString() {
    return 'NearbyPlace(placeId: $placeId, name: $name, address: $address, latitude: $latitude, longitude: $longitude, rating: $rating, userRatingsTotal: $userRatingsTotal, types: $types, priceLevel: $priceLevel)';
  }
}

/// ==============================
/// Helper model: coordinates
/// ==============================
class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates({required this.latitude, required this.longitude});

  @override
  String toString() {
    return 'Coordinates(latitude: $latitude, longitude: $longitude)';
  }
}

class DrivingRouteEstimate {
  const DrivingRouteEstimate({
    required this.distanceKm,
    required this.durationHours,
  });

  final double distanceKm;
  final double durationHours;
}
