import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// MapService
///
/// This service handles map-related logic for the travel app.
///
/// Main responsibilities:
/// - Search destination suggestions
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
  }) async {
    if (input.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places:autocomplete',
    );
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey},
      body: jsonEncode({
        'input': input.trim(),
        if (destinationCitiesOnly) 'includedPrimaryTypes': ['(cities)'],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch place suggestions.');
    }

    final data = jsonDecode(response.body);

    final suggestions = data['suggestions'] as List<dynamic>? ?? const [];

    return suggestions.map((item) {
      final prediction = item['placePrediction'] as Map<String, dynamic>? ?? {};
      return PlaceSuggestion(
        placeId: prediction['placeId'] ?? '',
        description: prediction['text']?['text'] ?? '',
      );
    }).toList();
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
            'places.types,places.priceLevel',
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

    return results.map((item) {
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
      );
    }).toList();
  }

  /// ==============================
  /// Geocode a text address into coordinates
  /// ==============================
  ///
  /// Example:
  /// "Ho Chi Minh City"
  ///
  /// Returns coordinates of the searched location
  Future<Coordinates> geocodeAddress(String address) async {
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

    final result = data['results'][0];
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
}

/// ==============================
/// Helper model: place suggestion
/// ==============================
class PlaceSuggestion {
  final String placeId;
  final String description;

  PlaceSuggestion({required this.placeId, required this.description});

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
  });

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
