import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/community/destination_review.dart';
import '../../models/community/destination_tip.dart';

class CommunityService {
  CommunityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('publicDestinationReviews');

  CollectionReference<Map<String, dynamic>> get _tips =>
      _firestore.collection('destinationTips');

  Future<void> publishReview(DestinationReview review) async {
    await _reviews.doc(review.id).set(review.toMap());
  }

  Future<void> publishTip(DestinationTip tip) async {
    await _tips.doc(tip.id).set(tip.toMap());
  }

  Stream<List<DestinationReview>> watchReviews({
    required String destinationName,
    String? destinationPlaceId,
  }) {
    final query = destinationPlaceId?.trim().isNotEmpty == true
        ? _reviews.where('destinationPlaceId', isEqualTo: destinationPlaceId)
        : _reviews.where(
            'destinationKey',
            isEqualTo: DestinationReview.normalizeDestinationKey(
              destinationName,
            ),
          );

    return query.snapshots().map((snapshot) {
      final reviews = snapshot.docs
          .map((doc) => DestinationReview.fromMap(doc.data(), doc.id))
          .where((review) => review.isPublished)
          .toList();
      reviews.sort((left, right) {
        final byDate = (right.createdAt ?? DateTime(1970)).compareTo(
          left.createdAt ?? DateTime(1970),
        );
        if (byDate != 0) return byDate;
        return right.rating.compareTo(left.rating);
      });
      return reviews;
    });
  }

  Stream<List<DestinationTip>> watchTips({
    required String destinationName,
    String? destinationPlaceId,
  }) {
    final query = destinationPlaceId?.trim().isNotEmpty == true
        ? _tips.where('destinationPlaceId', isEqualTo: destinationPlaceId)
        : _tips.where(
            'destinationKey',
            isEqualTo: DestinationTip.normalizeDestinationKey(destinationName),
          );

    return query.snapshots().map((snapshot) {
      final tips = snapshot.docs
          .map((doc) => DestinationTip.fromMap(doc.data(), doc.id))
          .where((tip) => tip.status == 'published')
          .toList();
      tips.sort((left, right) {
        final byLikes = right.likesCount.compareTo(left.likesCount);
        if (byLikes != 0) return byLikes;
        return (right.createdAt ?? DateTime(1970)).compareTo(
          left.createdAt ?? DateTime(1970),
        );
      });
      return tips;
    });
  }
}
