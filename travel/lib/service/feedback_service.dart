import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel/models/feedback.dart' as model;

class FeedbackService {
  final CollectionReference feedbackRef = FirebaseFirestore.instance.collection('feedbacks');

  /// CRUD
  
  // CREATE -- Save feedback
  Future<void> saveFeedback({
    required model.Feedback feedback,
  }) async {
    try {
      await feedbackRef
          .doc(feedback.id)
          .set(feedback.toMap());
    } catch (e) {
      throw Exception('Failed to save feedback: $e');
    }
  }
}