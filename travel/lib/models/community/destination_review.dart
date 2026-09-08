import 'package:cloud_firestore/cloud_firestore.dart';

class DestinationReview {
  final String id;
  final String ownerId;
  final String tripId;
  final String destinationName;
  final String destinationKey;
  final String? destinationPlaceId;
  final String displayName;
  final bool isAnonymous;
  final int rating;
  final List<String> tripStyleTags;
  final List<String> highlights;
  final List<String> mustTryFoods;
  final List<String> recommendedPlaces;
  final String body;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DestinationReview({
    required this.id,
    required this.ownerId,
    required this.tripId,
    required this.destinationName,
    required this.destinationKey,
    this.destinationPlaceId,
    required this.displayName,
    required this.isAnonymous,
    required this.rating,
    this.tripStyleTags = const [],
    this.highlights = const [],
    this.mustTryFoods = const [],
    this.recommendedPlaces = const [],
    required this.body,
    this.status = 'published',
    this.createdAt,
    this.updatedAt,
  });

  String get visibleName => isAnonymous ? 'Traveler' : displayName;

  bool get isPublished => status == 'published';

  factory DestinationReview.fromMap(Map<String, dynamic> data, String id) {
    return DestinationReview(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      destinationName: data['destinationName'] as String? ?? '',
      destinationKey: data['destinationKey'] as String? ?? '',
      destinationPlaceId: data['destinationPlaceId'] as String?,
      displayName: data['displayName'] as String? ?? 'Traveler',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      tripStyleTags: _stringList(data['tripStyleTags']),
      highlights: _stringList(data['highlights']),
      mustTryFoods: _stringList(data['mustTryFoods']),
      recommendedPlaces: _stringList(data['recommendedPlaces']),
      body: data['body'] as String? ?? '',
      status: data['status'] as String? ?? 'published',
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'tripId': tripId,
      'destinationName': destinationName,
      'destinationKey': destinationKey,
      'destinationPlaceId': destinationPlaceId,
      'displayName': displayName,
      'isAnonymous': isAnonymous,
      'rating': rating,
      'tripStyleTags': tripStyleTags,
      'highlights': highlights,
      'mustTryFoods': mustTryFoods,
      'recommendedPlaces': recommendedPlaces,
      'body': body,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String normalizeDestinationKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
