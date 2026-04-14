import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel/models/preference/preference_result.dart';
import 'package:travel/models/preference/preferences.dart';

class PreferenceService {
  final CollectionReference preferenceRef = FirebaseFirestore.instance.collection('preferences');

  /// CRUD
  
  // CREATE - add a new preference
  Future<PreferenceResult> addPreference(Preference preference) async {
    try {
      await preferenceRef.doc(preference.id).set(preference.toMap());
      return PreferenceResult(success: true, data: null, error: "");
    } catch (e) {
      return PreferenceResult(success: false, data: null, error: e.toString());
    }
  }

  // READ - by user id
  Future<PreferenceResult> getPreferences(String ownerId) async {
    try {
      final snapshot = await preferenceRef
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
      
      if(snapshot.docs.isEmpty) {
        return PreferenceResult(
          success: false, 
          data: null, 
          error: "No preference found",
        );
      }

      final doc = snapshot.docs.first;

      final preference = Preference.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );

      return PreferenceResult(
        success: true,
        data: preference,
        error: "",
      );
    } catch (e) {
      return PreferenceResult(
        success: false,
        data: null,
        error: e.toString(),
      );
    }
  }
}