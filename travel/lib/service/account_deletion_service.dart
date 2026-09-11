import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Removes everything a user owns in Firestore, ahead of deleting their
/// Firebase Auth account.
///
/// ORDER IS NOT ARBITRARY. Two constraints shape it:
///
/// 1. Delete itineraries by ownerId, including records whose parent trip is
///    already missing. Parent trips are removed afterwards.
///
/// 2. All of this must finish BEFORE the auth account is deleted. Once the
///    account is gone the user is signed out, `request.auth` is null, and the
///    rules deny everything. Anything left behind is unreachable forever.
class AccountDeletionService {
  final FirebaseFirestore _firestore;

  AccountDeletionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Firestore caps a batch at 500 writes. 400 leaves room and keeps each
  /// commit small enough to retry cheaply.
  static const _batchLimit = 400;

  /// Deletes every document owned by [uid].
  ///
  /// Throws if any step fails, deliberately: a partial delete followed by a
  /// successful auth deletion is the one outcome that cannot be recovered
  /// from, so the caller must not proceed to delete the account.
  Future<void> deleteDataForUser(String uid) async {
    if (uid.trim().isEmpty) throw ArgumentError.value(uid, 'uid');
    // Community contributions also contain account-linked personal data.
    for (final collection in ['publicDestinationReviews', 'destinationTips']) {
      final documents = await _firestore.collection(collection)
          .where('ownerId', isEqualTo: uid).get();
      await _deleteRefs(documents.docs.map((doc) => doc.reference).toList());
    }
    // Feedback first - its rule checks userId directly and never reads the
    // trip, so it is safe at any point, but doing it up front keeps the
    // trip-dependent work together below.
    debugPrint('[delete]   feedbacks: query');
    final feedbacks = await _firestore
        .collection('feedbacks')
        .where('userId', isEqualTo: uid)
        .get();
    debugPrint('[delete]   feedbacks: ${feedbacks.docs.length} to remove');
    await _deleteRefs(feedbacks.docs.map((doc) => doc.reference).toList());

    debugPrint('[delete]   trips: query');
    final trips = await _firestore
        .collection('trips')
        .where('ownerId', isEqualTo: uid)
        .get();

    final itineraries = await _firestore.collection('itineraries')
        .where('ownerId', isEqualTo: uid).get();
    await _deleteRefs(itineraries.docs.map((doc) => doc.reference).toList());

    // Now the trips themselves; nothing depends on them any more.
    debugPrint('[delete]   trips: removing');
    await _deleteRefs(trips.docs.map((doc) => doc.reference).toList());

    debugPrint('[delete]   preferences: query');
    final preferences = await _firestore
        .collection('preferences')
        .where('ownerId', isEqualTo: uid)
        .get();
    await _deleteRefs(preferences.docs.map((doc) => doc.reference).toList());

    // The profile document last: it is the cheapest thing to identify if any
    // of the above fails and the user retries.
    debugPrint('[delete]   users/$uid: removing');
    await _firestore.collection('users').doc(uid).delete();
    debugPrint('[delete]   firestore cascade complete');
  }

  Future<void> _deleteRefs(List<DocumentReference> refs) async {
    for (var start = 0; start < refs.length; start += _batchLimit) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(start).take(_batchLimit)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
