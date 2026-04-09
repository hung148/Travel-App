class Feedback{
  final String id;
  final double rating;
  final String best;
  final String worst;

  Feedback({
    required this.id,
    required this.rating,
    required this.best,
    required this.worst,
  });

  factory Feedback.fromMap(Map<String, dynamic> data, String id) {
    return Feedback(
      id: id,
      rating: data['rating'],
      best: data['best'],
      worst: data['worst'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rating': rating,
      'best': best,
      'worst': worst,
    };
  }
}