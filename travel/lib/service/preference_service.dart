import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel/models/preference/preference_result.dart';
import 'package:travel/models/preference/preferences.dart';

class PreferenceService {
  final CollectionReference preferenceRef = FirebaseFirestore.instance.collection('preferences');

  /// CRUD
  
  // CREATE - add a new preference
  Future<PreferenceResult> addPreference(Preference preference) {
    try {
      await preferenceRef.doc(preference.id).set(trip.toMap());
    } catch (e) {

    }
  }
}