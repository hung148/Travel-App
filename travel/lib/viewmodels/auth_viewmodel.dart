import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  late final StreamSubscription<AppUser?> _authSubscription;

  bool isLoading = true;
  String? errorMessage;
  AppUser? user;
  bool isNewUser = false;

  AuthViewModel(this._authService) {
    _authSubscription = _authService.authStateChanges.listen(
      (currentUser) {
        user = currentUser;
        isNewUser = currentUser != null && !currentUser.onboardingCompleted;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Failed to restore auth state: $error\n$stackTrace');
        isLoading = false;
        errorMessage = 'Unable to restore your session. Please try again.';
        notifyListeners();
      },
    );
  }

  Future<void> login(String email, String password) async {
    await _run(
      () async =>
          user = await _authService.login(email: email, password: password),
      'Unable to sign in. Please try again.',
    );
  }

  Future<void> register(String name, String email, String password) async {
    await _run(() async {
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

  Future<void> resetPassword(String email) async {
    await _run(
      () => _authService.resetPassword(email),
      'Unable to send the reset email.',
    );
  }

  Future<void> _run(Future<void> Function() action, String fallback) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
      await action();
    } catch (error, stackTrace) {
      debugPrint('$error\n$stackTrace');
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      errorMessage = message.isEmpty ? fallback : message;
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
