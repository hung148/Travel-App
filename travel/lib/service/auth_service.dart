import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

/// AuthService
///
/// This class handles all authentication logic for the app:
/// - Register (sign up)
/// - Login (sign in)
/// - Logout
/// - Reset password
///
/// Why use a service:
/// - Keeps Firebase logic out of UI
/// - Makes code reusable and clean
/// - Easier to maintain and scale
class AuthService {
  /// FirebaseAuth instance used throughout the app
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// ==============================
  /// Get current Firebase user
  /// ==============================
  User? get currentFirebaseUser => _auth.currentUser;

  /// ==============================
  /// Get current user as AppUser model
  /// ==============================
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AppUser.fromFirebaseUser(user);
  }

  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().asyncMap((firebaseUser) async {
        if (firebaseUser == null) return null;
        final snapshot = await _users.doc(firebaseUser.uid).get();
        if (!snapshot.exists) return AppUser.fromFirebaseUser(firebaseUser);
        final data = snapshot.data()!;
        return AppUser.fromMap({
          ...data,
          'uid': firebaseUser.uid,
          'email': firebaseUser.email ?? data['email'] ?? '',
          'name': firebaseUser.displayName ?? data['name'] ?? '',
          'profileImage': firebaseUser.photoURL ?? data['profileImage'],
        });
      });

  /// ==============================
  /// Register (Sign Up)
  /// ==============================
  ///
  /// Creates a new account using email and password,
  /// then updates the display name.
  ///
  /// Returns:
  /// - AppUser if successful
  /// - throws Exception if failed
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      /// Create user in Firebase Authentication
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = credential.user;

      if (user == null) {
        throw Exception('User creation failed.');
      }

      /// Update display name
      await user.updateDisplayName(name.trim());

      /// Reload to ensure updated data
      await user.reload();

      user = _auth.currentUser;

      if (user == null) {
        throw Exception('User reload failed.');
      }

      final appUser = AppUser.fromFirebaseUser(user);
      await _users.doc(user.uid).set({
        ...appUser.toMap(),
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return appUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleError(e));
    } catch (e) {
      throw Exception('Register error: $e');
    }
  }

  Future<void> completeOnboarding(String uid) async {
    await _users.doc(uid).set({
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ==============================
  /// Login (Sign In)
  /// ==============================
  ///
  /// Logs in an existing user using email and password
  ///
  /// Returns:
  /// - AppUser if successful
  /// - throws Exception if failed
 Future<AppUser> login({
  required String email,
  required String password,
}) async {
  try {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('Login failed.');
    }

    final snapshot = await _users.doc(firebaseUser.uid).get();

    if (!snapshot.exists) {
      final appUser = AppUser.fromFirebaseUser(firebaseUser);

      await _users.doc(firebaseUser.uid).set({
        ...appUser.toMap(),
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return appUser;
    }

    final data = snapshot.data()!;

    return AppUser.fromMap({
      ...data,
      'uid': firebaseUser.uid,
      'email': firebaseUser.email ?? data['email'] ?? '',
      'name': firebaseUser.displayName ?? data['name'] ?? '',
      'profileImage':
          firebaseUser.photoURL ?? data['profileImage'],
    });
  } on FirebaseAuthException catch (e) {
    throw Exception(_handleError(e));
  } catch (e) {
    throw Exception('Login error: $e');
  }
}
  /// ==============================
  /// Logout
  /// ==============================
  ///
  /// Signs out the current user
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Logout error: $e');
    }
  }

  /// ==============================
  /// Reset Password
  /// ==============================
  ///
  /// Sends a password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleError(e));
    } catch (e) {
      throw Exception('Reset password error: $e');
    }
  }

  /// ==============================
  /// Handle Firebase Auth Errors
  /// ==============================
  ///
  /// Converts Firebase error codes into readable messages
  String _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }
}
