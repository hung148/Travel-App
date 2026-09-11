import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travel/models/itinerary.dart';

class ItineraryService {
  final CollectionReference itineraryRef = FirebaseFirestore.instance
      .collection("itineraries");

  /// CRUD

  // CREATE - save a list of itineraries
  Future<void> saveItinerary(List<Itinerary> itineraries) async {
    try {
      // Stamped on every document so the security rules can check ownership
      // from the document itself. Without it the rules have to read the trip
      // once per itinerary, which is slower, billable, and runs into the
      // per-request limit on document lookups for a long trip.
      final ownerId = FirebaseAuth.instance.currentUser?.uid;
      if (ownerId == null) {
        throw Exception('Cannot save an itinerary while signed out.');
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final item in itineraries) {
        final docRef = itineraryRef.doc('${item.tripId}_day_${item.dayNumber}');

        batch.set(docRef, {...item.toMap(), 'ownerId': ownerId});
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save itinerary: $e');
    }
  }

  // READ - get list of itinerary
  Future<List<Itinerary>> getItinerary(String tripId) async {
    try {
      final ownerId = FirebaseAuth.instance.currentUser?.uid;
      if (ownerId == null) {
        throw Exception('Cannot load an itinerary while signed out.');
      }
      final snapshot = await itineraryRef
          .where('ownerId', isEqualTo: ownerId)
          .where('tripId', isEqualTo: tripId)
          .orderBy('dayNumber') // need a Firestore index for this query.
          .get();

      return snapshot.docs.map((doc) {
        return Itinerary.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load itinerary: $e');
    }
  }
}
