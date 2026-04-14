import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel/models/itinerary.dart';

class ItineraryService {
  final CollectionReference itineraryRef = FirebaseFirestore.instance.collection("itineraries");

   /// CRUD
   
   // CREATE - save a list of itineraries
   Future<void> saveItinerary(List<Itinerary> itineraries) async {
    try {
       final batch = FirebaseFirestore.instance.batch();

       for (final item in itineraries) {
        final docRef = itineraryRef.doc(item.id);

        batch.set(docRef, item.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save itinerary: $e');
    }
   }
   
   // READ - get list of itinerary
   Future<List<Itinerary>> getItinerary(String tripId) async {
    try {
      final snapshot = await itineraryRef
        .where('tripId', isEqualTo: tripId)
        .orderBy('dayNumber') // need a Firestore index for this query.
        .get();

      return snapshot.docs.map((doc) {
        return Itinerary.fromMap(
          doc.data() as Map<String, dynamic>, 
          doc.id,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failt to laod itinerary: $e');
    }
   }
}