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

  /// Constructor
  ///
  /// Example:
  /// final mapService = MapService(apiKey: 'YOUR_API_KEY');
  MapService({required this.apiKey});

  /// ==============================
  /// Get autocomplete place suggestions
  /// ==============================
  ///
  /// Example input:
  /// "Paris"
  ///
  /// Returns a list of place suggestions from Google Places API
  Future<List<PlaceSuggestion>> getPlaceSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input.trim())}'
      '&key=$apiKey',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch place suggestions.');
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      throw Exception(data['error_message'] ?? 'Autocomplete error.');
    }

    final predictions = data['predictions'] as List<dynamic>;

    return predictions.map((item) {
      return PlaceSuggestion(
        placeId: item['place_id'] ?? '',
        description: item['description'] ?? '',
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
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=place_id,name,formatted_address,geometry,rating,types'
      '&key=$apiKey',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch place details.');
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 'OK') {
      throw Exception(data['error_message'] ?? 'Place details error.');
    }

    final result = data['result'];

    return PlaceDetails(
      placeId: result['place_id'] ?? '',
      name: result['name'] ?? '',
      address: result['formatted_address'] ?? '',
      latitude: result['geometry']?['location']?['lat']?.toDouble() ?? 0.0,
      longitude: result['geometry']?['location']?['lng']?.toDouble() ?? 0.0,
      rating: (result['rating'] ?? 0).toDouble(),
      types: List<String>.from(result['types'] ?? []),
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
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$latitude,$longitude'
      '&radius=$radius'
      '&type=${Uri.encodeComponent(type)}'
      '&key=$apiKey',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch nearby places.');
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      throw Exception(data['error_message'] ?? 'Nearby search error.');
    }

    final results = data['results'] as List<dynamic>;

    return results.map((item) {
      return NearbyPlace(
        placeId: item['place_id'] ?? '',
        name: item['name'] ?? '',
        address: item['vicinity'] ?? '',
        latitude: item['geometry']?['location']?['lat']?.toDouble() ?? 0.0,
        longitude: item['geometry']?['location']?['lng']?.toDouble() ?? 0.0,
        rating: (item['rating'] ?? 0).toDouble(),
        userRatingsTotal: item['user_ratings_total'] ?? 0,
        types: List<String>.from(item['types'] ?? []),
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

    final response = await http.get(uri);

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
}

/// ==============================
/// Helper model: place suggestion
/// ==============================
class PlaceSuggestion {
  final String placeId;
  final String description;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
  });

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

  NearbyPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingsTotal,
    required this.types,
  });

  @override
  String toString() {
    return 'NearbyPlace(placeId: $placeId, name: $name, address: $address, latitude: $latitude, longitude: $longitude, rating: $rating, userRatingsTotal: $userRatingsTotal, types: $types)';
  }
}

/// ==============================
/// Helper model: coordinates
/// ==============================
class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates({
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() {
    return 'Coordinates(latitude: $latitude, longitude: $longitude)';
  }
}