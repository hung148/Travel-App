import 'package:travel/models/preference/preferences.dart';

// detail error if fail
class PreferenceResult {
  final bool success;
  final Preference? data;
  final String? error;

  const PreferenceResult({
    required this.success,
    required this.data,
    required this.error,
  });
}