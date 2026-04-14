import 'package:flutter/material.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/service/preference_service.dart';

class PreferenceViewmodel extends ChangeNotifier {
  final PreferenceService _preferenceService;

  PreferenceViewmodel(this._preferenceService);

  Preference? preference;
  bool isLoading = false;
  String? errorMessage;
  bool savedSuccessfully = false;

  /// Load preferences for a user
  Future<void> loadPreferences(String ownerId) async {
    try {
      isLoading = true;
      errorMessage = null;
      savedSuccessfully = false;
      notifyListeners();

      final result = await _preferenceService.getPreferences(ownerId);

      if (result.success) {
        preference = result.data;
      } else {
        errorMessage = result.error;
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Save or update preferences
  Future<void> savePreferences(Preference pref) async {
    try {
      isLoading = true;
      errorMessage = null;
      savedSuccessfully = false;
      notifyListeners();

      final result = await _preferenceService.addPreference(pref);

      if (result.success) {
        preference = pref;
        savedSuccessfully = true;
      } else {
        errorMessage = result.error;
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}