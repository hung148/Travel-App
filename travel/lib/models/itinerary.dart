class Itinerary {
  final String id;
  final int dayNumber;
  final String places;
  final String meals;
  final double estimatedCost;

  Itinerary({
    required this.id,
    required this.dayNumber,
    required this.places,
    required this.meals,
    required this.estimatedCost,
  });

  factory Itinerary.fromMap(Map<String, dynamic> data, String id) {
    return Itinerary(
      id: id, 
      dayNumber: data['dayNumber'], 
      places: data['places'], 
      meals: data['meals'], 
      estimatedCost: data['estimatedCost'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dayNumber': dayNumber,
      'places': places,
      'meals': meals,
      'estimatedCost': estimatedCost, 
    };
  }
}