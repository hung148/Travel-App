class Feedback{
  final String id;
  final String userId;
  final String tripId; 
  final double rating;
  final String best;
  final String worst;

  Feedback({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.rating,
    required this.best,
    required this.worst,
  });

  factory Feedback.fromMap(Map<String, dynamic> data, String id) {
    return Feedback(
      id: id,
      userId: data['userId'] ?? '',
      tripId: data['tripId'] ?? '',
      rating: (data['rating'] as num).toDouble(), // Firestore returns num, so Dart can complain sometimes.
      best: data['best'] ?? '',
      worst: data['worst'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tripId': tripId,
      'rating': rating,
      'best': best,
      'worst': worst,
    };
  }
}