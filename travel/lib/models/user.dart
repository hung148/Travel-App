/// user.dart
///
/// This file defines the AppUser model for your travel app.
///
/// Why we use this:
/// - It gives your app a clean user object
/// - It helps store user data in Firestore
/// - It helps read Firestore data back into Dart
/// - It keeps your code organized and easier to manage
///
/// We use AppUser instead of User because Firebase Auth already has
/// its own class called User, and using the same name can cause confusion.

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

  /// Main constructor
  ///
  /// required means these fields must be provided when creating an AppUser.
  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImage,
  });

  /// Converts this AppUser object into a Map
  ///
  /// Why needed:
  /// Firestore stores data as key-value pairs, so before saving user data,
  /// we convert the object into a Map<String, dynamic>.
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
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profileImage: map['profileImage'],
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
    String? profileImage,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
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
        other.profileImage == profileImage;
  }

  /// Required when overriding ==
/// Helps Dart generate a combined hash value for this object
  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        email.hashCode ^
        profileImage.hashCode;
  }
}
