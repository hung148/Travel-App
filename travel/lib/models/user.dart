// user.dart
//
// AppUser is the app's domain user, separate from Firebase Auth's User type.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  /// Unique id from Firebase Authentication
  final String uid;

  /// User's display name
  final String name;

  /// User's email address
  final String email;

  /// Optional profile image URL
  /// This can be null if the user has not uploaded an image
  final String? profileImage;

  /// Whether the user has finished the onboarding flow.
  final bool onboardingCompleted;

  /// When the account profile was created in Firestore.
  final DateTime? createdAt;

  /// When the profile or account metadata was last refreshed.
  final DateTime? updatedAt;

  /// Main constructor
  ///
  /// required means these fields must be provided when creating an AppUser.
  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImage,
    this.onboardingCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Converts this AppUser object into a Map
  ///
  /// Why needed:
  /// Firestore stores data as key-value pairs, so before saving user data,
  /// we convert the object into a `Map<String, dynamic>`.
  ///
  /// Example output:
  /// {
  ///   'uid': 'abc123',
  ///   'name': 'Min',
  ///   'email': 'min@email.com',
  ///   'profileImage': 'https://...'
  /// }
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'photoUrl': profileImage,
      'displayName': name,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  /// Creates an AppUser object from a Map
  ///
  /// Why needed:
  /// When reading from Firestore, you get data back as a Map.
  /// This factory constructor turns that Map into a proper AppUser object.
  ///
  /// ?? '' means:
  /// if the value is null, use an empty string instead
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? map['displayName'] ?? '',
      email: map['email'] ?? '',
      profileImage: map['profileImage'] ?? map['photoUrl'],
      onboardingCompleted: map['onboardingCompleted'] == true,
      createdAt: _dateFromFirestore(map['createdAt']),
      updatedAt: _dateFromFirestore(map['updatedAt']),
    );
  }

  /// Creates an AppUser directly from Firebase Auth's User object
  ///
  /// Why this is useful:
  /// After login or signup, Firebase gives you a User.
  /// This method helps convert that Firebase user into your own app model.
  ///
  /// displayName, email, and photoURL may be null in Firebase,
  /// so we safely handle them.
  factory AppUser.fromFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      profileImage: user.photoURL,
      createdAt: user.metadata.creationTime,
      updatedAt: user.metadata.lastSignInTime,
    );
  }

  /// copyWith lets you create a new AppUser by changing only some fields
  ///
  /// Why useful:
  /// If you want to update only the name or profile image,
  /// you do not need to rebuild the whole object manually.
  ///
  /// Example:
  /// final updatedUser = oldUser.copyWith(name: 'New Name');
  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    Object? profileImage = _notProvided,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: identical(profileImage, _notProvided)
          ? this.profileImage
          : profileImage as String?,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Optional: Convert object to a readable string
  ///
  /// Helpful for debugging in print statements
  @override
  String toString() {
    return 'AppUser(uid: $uid, name: $name, email: $email, profileImage: $profileImage)';
  }

  /// Optional: Lets Dart compare two AppUser objects by value
  ///
  /// This means two AppUser objects with the same data
  /// can be treated as equal.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppUser &&
        other.uid == uid &&
        other.name == name &&
        other.email == email &&
        other.profileImage == profileImage &&
        other.onboardingCompleted == onboardingCompleted &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  /// Required when overriding ==
  /// Helps Dart generate a combined hash value for this object
  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        email.hashCode ^
        profileImage.hashCode ^
        onboardingCompleted.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

const Object _notProvided = Object();

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
