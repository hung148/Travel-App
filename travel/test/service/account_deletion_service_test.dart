import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/service/account_deletion_service.dart';

void main() {
  test('deletes private data and community contributions, preserves other owners', () async {
    final db = FakeFirebaseFirestore();
    for (final uid in ['target', 'other']) {
      await db.collection('users').doc(uid).set({'uid': uid});
      for (final collection in ['trips', 'preferences', 'publicDestinationReviews', 'destinationTips']) {
        await db.collection(collection).doc(uid).set({'ownerId': uid});
      }
      await db.collection('feedbacks').doc(uid).set({'userId': uid});
      // Legacy itinerary without ownerId must still be deleted via its trip.
      await db.collection('itineraries').doc(uid).set({'tripId': uid});
    }
    await AccountDeletionService(firestore: db).deleteDataForUser('target');
    for (final collection in ['users', 'trips', 'preferences', 'publicDestinationReviews', 'destinationTips', 'feedbacks', 'itineraries']) {
      final snapshot = await db.collection(collection).get();
      expect(snapshot.docs.map((doc) => doc.id), ['other'], reason: collection);
    }
    // Retry after a completed deletion is safe.
    await AccountDeletionService(firestore: db).deleteDataForUser('target');
  });
  test('handles more than one Firestore batch', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('trips').doc('trip').set({'ownerId': 'user'});
    for (var i = 0; i < 405; i++) {
      await db.collection('itineraries').doc('day-$i').set({'tripId': 'trip'});
    }
    await AccountDeletionService(firestore: db).deleteDataForUser('user');
    expect((await db.collection('itineraries').get()).docs, isEmpty);
    expect((await db.collection('trips').get()).docs, isEmpty);
  });
}
