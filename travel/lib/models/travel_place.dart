class TravelPlace {
  final String id;
  final String name;
  final String category;
  final List<String> tags;

  final double rating;
  final int reviewCount;

  final double estimatedCost;

  final double latitude;
  final double longitude;

  final int estimatedVisitMinutes;

  const TravelPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    required this.estimatedCost,
    required this.latitude,
    required this.longitude,
    required this.estimatedVisitMinutes,
  });

  bool get isDining {
    final types = {category, ...tags}.map((value) => value.toLowerCase());
    return types.any(
      (type) =>
          type == 'restaurant' ||
          type.endsWith('_restaurant') ||
          type == 'cafe' ||
          type == 'bakery' ||
          type == 'meal_takeaway' ||
          type == 'meal_delivery',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'tags': tags,
      'rating': rating,
      'reviewCount': reviewCount,
      'estimatedCost': estimatedCost,
      'latitude': latitude,
      'longitude': longitude,
      'estimatedVisitMinutes': estimatedVisitMinutes,
    };
  }

  factory TravelPlace.fromMap(Map<String, dynamic> data) {
    return TravelPlace(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      tags: (data['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble() ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      estimatedVisitMinutes:
          (data['estimatedVisitMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}
