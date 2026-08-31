class Itinerary {
  final String id;
  final String tripId;
  final int dayNumber;
  final String places;
  final String meals;
  final double estimatedCost;

  Itinerary({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.places,
    required this.meals,
    required this.estimatedCost,
  });

  factory Itinerary.fromMap(Map<String, dynamic> data, String id) {
    return Itinerary(
      id: id,
      tripId: data['tripId'] ?? '',
      dayNumber: (data['dayNumber'] as num?)?.toInt() ?? 0,
      places: data['places'] as String? ?? '',
      meals: data['meals'] as String? ?? '',
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'dayNumber': dayNumber,
      'places': places,
      'meals': meals,
      'estimatedCost': estimatedCost,
    };
  }
}
