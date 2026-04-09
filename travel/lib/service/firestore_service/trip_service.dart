import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/trip/trip_result.dart';

class TripService {

  // Reference to Trip collection
  // FirebaseFirestore.instance gives you the Firestore database you app is connected to.
  // collection('trips') this selects the collection named "trips" inside Firestore
  final CollectionReference tripRef = FirebaseFirestore.instance.collection('trips');

  

  // CRUD 
  // CREATE - Add a new trip
  Future<TripResult> addTrip(Trip trip) async {
    try {

      // doc(trip.id) selects a specific document inside the trips collection 
      // if the document does not exist, Firestore will create it.
      // If it already exists, Firestore will overwrite it (because .set() overwrites)
      // .set(trip.toMap()) this writes data into that document
      // await tells flutter to wait for Firestore finishes saving before continuing
      await tripRef.doc(trip.id).set(trip.toMap());
      return TripResult(success: true, data: null, error: "");
    } catch (e) {
      return TripResult(success: false, data: null, error: e.toString());
    }
  }

  // READ - Get a single trip by ID
  Future<TripResult> getTripById(String id) async {
    try {
      // get trip document 
      final doc = await tripRef.doc(id).get();

      if (!doc.exists) {
        return TripResult(
          success: false,
          data: null,
          error: "Trip not found",
        );
      }

      // convert trip doc to Trip object
      final trip = Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      return TripResult(
        success: true, 
        data: trip, 
        error: "",
      );
    } catch (e) {
      return TripResult(
        success: false, 
        data: null, 
        error: e.toString(),
      );
    }
  }

  // READ - Get all trips all of a user
  // Stream is like a pipe that keeps sending new data whenever something changes.
  // snapshots() gives you live updates from Firestore
  // use this with StreamBuilder
  Stream<List<Trip>> getTripsByUser() async* {
    yield [];
  }
  
}