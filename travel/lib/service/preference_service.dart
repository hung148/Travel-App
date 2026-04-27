import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel/config/app_config.dart';
import 'package:travel/models/preference/preference_result.dart';
import 'package:travel/models/preference/preferences.dart';

class PreferenceService {
  final CollectionReference preferenceRef = FirebaseFirestore.instance.collection('preferences');

    // Fake data
    static final Preference _fakePreference = Preference(
      id: 'debug-preference-id',
      ownerId: 'test-user',
      experienceType: ['nature', 'food'],
      activityLevel: 'hyper active',
      spendingStyle: 'I pay for the whole trip',
      interests: ['exploring', 'coffee'],
    );

  /// CRUD
  
  // CREATE - add a new preference
  Future<PreferenceResult> addPreference(Preference preference) async {
    if (AppConfig.isDebug) {
      return PreferenceResult(success: true, data: null, error: "");
    }

    try {
      await preferenceRef.doc(preference.id).set(preference.toMap());
      return PreferenceResult(success: true, data: null, error: "");
    } catch (e) {
      return PreferenceResult(success: false, data: null, error: e.toString());
    }
  }

  // READ - by user id
  Future<PreferenceResult> getPreferences(String ownerId) async {
    if (AppConfig.isDebug) {
      return PreferenceResult(success: true, data: _fakePreference, error: "");
    }

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