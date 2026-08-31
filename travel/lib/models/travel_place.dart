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
}