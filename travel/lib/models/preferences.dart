/// preference.dart
///
/// This file defines the user's travel preferences.
/// These preferences are VERY IMPORTANT because:
/// - They guide AI recommendations
/// - They affect budget allocation
/// - They influence itinerary generation
///
/// Example:
/// - Nature vs Food vs History
/// - Chill vs Active trip
/// - Budget vs Luxury
/// - Interests like coffee, shopping, etc.

class Preference {
  /// Type of experience the user wants
  /// Examples:
  /// - "Nature"
  /// - "History"
  /// - "Food"
  /// - "Mix"
  final String experienceType;

  /// How active the user wants the trip
  /// Examples:
  /// - "Relaxed"
  /// - "Moderate"
  /// - "Very Active"
  final String activityLevel;

  /// Spending style of the user
  /// Examples:
  /// - "Budget"
  /// - "Normal"
  /// - "Luxury"
  final String spendingStyle;

  /// List of interests
  /// Examples:
  /// - ["Coffee", "Shopping", "Beach"]
  final List<String> interests;

  /// Constructor
  ///
  /// All fields are required because preferences
  /// should always be fully defined after onboarding.
  Preference({
    required this.experienceType,
    required this.activityLevel,
    required this.spendingStyle,
    required this.interests,
  });

  /// Convert Preference -> Map (for Firestore)
  ///
  /// Firestore stores data as key-value pairs,
  /// so we convert this object into a Map.
  Map<String, dynamic> toMap() {
    return {
      'experienceType': experienceType,
      'activityLevel': activityLevel,
      'spendingStyle': spendingStyle,
      'interests': interests,
    };
  }

  /// Convert Firestore Map -> Preference
  ///
  /// This is used when reading user preferences from Firestore.
  factory Preference.fromMap(Map<String, dynamic> map) {
    return Preference(
      experienceType: map['experienceType'] ?? '',
      activityLevel: map['activityLevel'] ?? '',
      spendingStyle: map['spendingStyle'] ?? '',
      interests: List<String>.from(map['interests'] ?? []),
    );
  }

  /// copyWith method
  ///
  /// Lets you update only specific fields without recreating everything.
  ///
  /// Example:
  /// preference = preference.copyWith(spendingStyle: "Luxury");
  Preference copyWith({
    String? experienceType,
    String? activityLevel,
    String? spendingStyle,
    List<String>? interests,
  }) {
    return Preference(
      experienceType: experienceType ?? this.experienceType,
      activityLevel: activityLevel ?? this.activityLevel,
      spendingStyle: spendingStyle ?? this.spendingStyle,
      interests: interests ?? this.interests,
    );
  }

  /// Debug print (optional but useful)
  @override
  String toString() {
    return 'Preference(experienceType: $experienceType, activityLevel: $activityLevel, spendingStyle: $spendingStyle, interests: $interests)';
  }

  /// Equality check (compare values, not memory)
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Preference &&
        other.experienceType == experienceType &&
        other.activityLevel == activityLevel &&
        other.spendingStyle == spendingStyle &&
        _listEquals(other.interests, interests);
  }

  /// HashCode (required when overriding ==)
  @override
  int get hashCode {
    return experienceType.hashCode ^
        activityLevel.hashCode ^
        spendingStyle.hashCode ^
        interests.hashCode;
  }

  /// Helper function to compare lists
  ///
  /// Dart does NOT compare lists by content automatically
  /// so we need to manually check each item
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}