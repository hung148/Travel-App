import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  late final StreamSubscription<AppUser?> _authSubscription;

  bool isLoading = true;
  bool isRestoringSession = true;
  String? errorMessage;
  AppUser? user;
  bool isNewUser = false;

  AuthViewModel(this._authService) {
    _authSubscription = _authService.authStateChanges.listen(
      (currentUser) {
        user = currentUser;
        isNewUser = currentUser != null && !currentUser.onboardingCompleted;
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
    }, 'Unable to sign out.');
  }

  Future<bool> resetPassword(String email) async {
    return _run(
      () => _authService.resetPassword(email),
      'Unable to send the reset email.',
    );
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
