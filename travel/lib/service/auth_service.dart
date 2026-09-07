import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'auth_rest_client.dart';

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
  final AuthRestClient _restClient;

  AuthService({AuthRestClient? restClient})
    : _restClient = restClient ?? AuthRestClient();

  /// Whether reauthenticate/delete must go over REST instead of the plugin.
  ///
  /// firebase_auth's Windows and Linux implementations reply on a non-platform
  /// thread for these calls; Flutter discards the message and the Future never
  /// completes - a hang with no error to catch. Everywhere else the plugin is
  /// the better path, because it keeps the SDK's own session state in step.
  static bool get _needsRestFallback {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Token from the REST re-authentication, held between the reauth and the
  /// delete. Only used on the REST path, and cleared as soon as it is spent.
  String? _restIdToken;

  String get _apiKey => _auth.app.options.apiKey;

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
      ///
      /// The password is passed through exactly as typed. Trimming it here
      /// would disagree with Firebase's own password reset page, which does
      /// not trim - a password with a leading or trailing space would then be
      /// impossible to sign in with.
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
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

      /// Send the verification email, but never let it fail or delay the
      /// signup. The account already exists by now and nothing below depends
      /// on the mail, so awaiting it only adds a network round trip to the
      /// time the user spends staring at the signup form. Errors are handled
      /// inside sendEmailVerification, which never throws.
      unawaited(sendEmailVerification());

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
        password: password,
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
        'profileImage': firebaseUser.photoURL ?? data['profileImage'],
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
  /// Email verification
  /// ==============================
  ///
  /// True once the signed-in user has clicked the link in the verification
  /// email. Firebase caches this on the client, so call [reloadUser] first if
  /// you need a fresh answer.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Sends (or re-sends) the verification email to the signed-in user.
  ///
  /// Returns whether the mail went out. Errors are reported through the
  /// return value rather than thrown, because during registration this is a
  /// side task that must never fail the signup, while the resend button does
  /// want to know. Firebase rate-limits this call, so a rapid second press
  /// answers false with a `too-many-requests` code.
  Future<bool> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (user.emailVerified) return true;
    try {
      await user.sendEmailVerification();
      return true;
    } catch (error) {
      debugPrint('Could not send verification email: $error');
      return false;
    }
  }

  /// Pulls the latest user record from Firebase (display name, emailVerified).
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (error) {
      debugPrint('Could not reload user: $error');
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
      /// An unknown address is not reported as an error. Telling the caller
      /// "no account exists here" would let anyone test which emails are
      /// registered, so the UI shows the same confirmation either way.
      if (e.code == 'user-not-found') {
        debugPrint('Password reset requested for an unknown email.');
        return;
      }
      throw Exception(_handleError(e));
    } catch (e) {
      throw Exception('Reset password error: $e');
    }
  }

  /// ==============================
  /// Re-authenticate
  /// ==============================
  ///
  /// Proves the person at the keyboard is the account holder, by asking for
  /// the password again. Firebase demands this before destructive operations
  /// when the sign-in is more than a few minutes old, and it doubles as the
  /// confirmation step for account deletion.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw Exception('You are not signed in.');
    }

    if (_needsRestFallback) {
      // Verifying the password over REST returns a fresh ID token, which is
      // exactly what the delete call needs a moment later.
      _restIdToken = await _restClient.signInForIdToken(
        apiKey: _apiKey,
        email: email,
        password: password,
      );
      return;
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleError(e));
    } catch (e) {
      throw Exception('Re-authentication error: $e');
    }
  }

  /// ==============================
  /// Delete the Firebase Auth account
  /// ==============================
  ///
  /// Irreversible, and the LAST step of account deletion - once this returns,
  /// the user is signed out and their Firestore documents are unreachable.
  /// Delete their data first.
  Future<void> deleteAuthAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (_needsRestFallback) {
      final token = _restIdToken;
      if (token == null) {
        // Only reachable if the caller skipped re-authentication, which the
        // whole flow depends on. Fail loudly rather than delete unverified.
        throw Exception('Confirm your password before deleting the account.');
      }
      await _restClient.deleteAccount(apiKey: _apiKey, idToken: token);
      _restIdToken = null;

      // The account is gone on the server, but this client still holds a
      // session for it. Signing out clears that and makes authStateChanges
      // emit null, which is what moves the app back to the login screen.
      await _auth.signOut();
      return;
    }

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleError(e));
    } catch (e) {
      throw Exception('Account deletion error: $e');
    }
  }

  /// ==============================
  /// Handle Firebase Auth Errors
  /// ==============================
  ///
  /// Converts Firebase error codes into readable messages
  String _handleError(FirebaseAuthException e) {
    return authErrorMessage(e.code, fallback: e.message);
  }

  static String authErrorMessage(String code, {String? fallback}) {
    switch (code) {
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
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Unable to connect. Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not currently available.';
      case 'missing-email':
        return 'Enter your email address.';
      case 'requires-recent-login':
        return 'For your security, sign in again before deleting your account.';
      default:
        return fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : 'Authentication failed. Please try again.';
    }
  }
}
