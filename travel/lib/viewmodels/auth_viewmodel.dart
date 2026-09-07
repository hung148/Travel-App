import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/account_deletion_service.dart';
import 'package:travel/service/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  final AccountDeletionService _deletionService;
  late final StreamSubscription<AppUser?> _authSubscription;

  bool isLoading = true;
  bool isRestoringSession = true;
  String? errorMessage;
  AppUser? user;
  bool isNewUser = false;

  /// Whether the signed-in user has confirmed their email address.
  ///
  /// Kept as state rather than read straight from FirebaseAuth on every build,
  /// because Firebase caches this on the ID token: clicking the link in the
  /// inbox does not notify the running app. It changes only when the auth
  /// stream fires or [refreshVerificationStatus] is called.
  bool isEmailVerified = false;

  AuthViewModel(this._authService, this._deletionService) {
    _authSubscription = _authService.authStateChanges.listen(
      (currentUser) {
        user = currentUser;
        isNewUser = currentUser != null && !currentUser.onboardingCompleted;
        isEmailVerified = currentUser != null && _authService.isEmailVerified;
        isLoading = false;
        isRestoringSession = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Failed to restore auth state: $error\n$stackTrace');
        isLoading = false;
        isRestoringSession = false;
        errorMessage = 'Unable to restore your session. Please try again.';
        notifyListeners();
      },
    );
  }

  Future<bool> login(String email, String password) async {
    return _run(() async {
      final loggedInUser = await _authService.login(
        email: email,
        password: password,
      );

      user = loggedInUser;
      isNewUser = !loggedInUser.onboardingCompleted;
      isEmailVerified = _authService.isEmailVerified;
    }, 'Unable to sign in. Please try again.');
  }

  Future<bool> register(String name, String email, String password) async {
    return _run(() async {
      user = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      isNewUser = true;
      isEmailVerified = _authService.isEmailVerified;
    }, 'Unable to create your account.');
  }

  Future<void> completeOnboarding() async {
    final currentUser = user;
    if (currentUser == null) return;
    await _authService.completeOnboarding(currentUser.uid);
    user = currentUser.copyWith(onboardingCompleted: true);
    isNewUser = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _run(() async {
      await _authService.logout();
      user = null;
      isNewUser = false;
      isEmailVerified = false;
    }, 'Unable to sign out.');
  }

  Future<bool> resetPassword(String email) async {
    return _run(
      () => _authService.resetPassword(email),
      'Unable to send the reset email.',
    );
  }

  /// Asks Firebase for a fresh copy of the user and re-reads the verified
  /// flag. This is the only way the app learns that the link in the inbox was
  /// clicked, so the verify screen calls it on a timer and on demand.
  Future<bool> refreshVerificationStatus() async {
    await _authService.reloadUser();
    final verified = _authService.isEmailVerified;
    if (verified != isEmailVerified) {
      isEmailVerified = verified;
      notifyListeners();
    }
    return verified;
  }

  /// Re-sends the verification email. False means it did not go out - most
  /// often because Firebase is rate-limiting repeated presses.
  Future<bool> resendEmailVerification() =>
      _authService.sendEmailVerification();

  /// Permanently deletes the signed-in user's data and their account.
  ///
  /// Three steps, and the order is the whole design:
  ///   1. Re-authenticate. Firebase requires a fresh sign-in for destructive
  ///      operations, and asking for the password is also the confirmation -
  ///      an account cannot be destroyed by one stray tap.
  ///   2. Delete every Firestore document they own. This has to happen while
  ///      they are still signed in, because the rules answer on request.auth.
  ///   3. Delete the auth account.
  ///
  /// If step 2 throws, step 3 never runs, so the user still has an account
  /// and can retry. The opposite order would strand their data permanently.
  Future<bool> deleteAccount(String password) async {
    return _run(() async {
      final currentUser = user;
      if (currentUser == null) {
        throw Exception('You are not signed in.');
      }

      // Step markers so a hang can be located from the console instead of
      // guessed at. Whichever "start" is the last line printed is the call
      // that did not come back.
      debugPrint('[delete] step 1/3 reauthenticate: start');
      await _authService.reauthenticateWithPassword(password);
      debugPrint('[delete] step 1/3 reauthenticate: done');

      debugPrint('[delete] step 2/3 firestore data: start');
      await _deletionService.deleteDataForUser(currentUser.uid);
      debugPrint('[delete] step 2/3 firestore data: done');

      debugPrint('[delete] step 3/3 auth account: start');
      await _authService.deleteAuthAccount();
      debugPrint('[delete] step 3/3 auth account: done');

      user = null;
      isNewUser = false;
      isEmailVerified = false;
    }, 'Unable to delete your account.');
  }

  /// Drops a stale error message.
  ///
  /// [errorMessage] lives on this view model for the whole app, so a failed
  /// sign-in would otherwise still be on screen after navigating to sign up.
  /// Each auth page clears it on the way in.
  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action, String fallback) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
      await action();
      return true;
    } catch (error, stackTrace) {
      debugPrint('$error\n$stackTrace');
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      errorMessage = message.isEmpty ? fallback : message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
