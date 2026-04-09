import 'package:firebase_auth/firebase_auth.dart';
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
      UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
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

      /// Convert Firebase User -> AppUser
      return AppUser.fromFirebaseUser(user);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleError(e));
    } catch (e) {
      throw Exception('Register error: $e');
    }
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
      UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = credential.user;

      if (user == null) {
        throw Exception('Login failed.');
      }

      return AppUser.fromFirebaseUser(user);
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