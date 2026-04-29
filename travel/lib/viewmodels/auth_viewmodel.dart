import 'package:flutter/material.dart';
import 'package:travel/config/app_config.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;

  bool isLoading = false;
  String? errorMessage;
  AppUser? user;
  bool isNewUser = false;

  AuthViewModel(this._authService);

  // Login
  Future<void> login(String email, String password) async {
    if (AppConfig.isDebug) {
      await _fakeLogin(); // use fake data in debug mode
      return;
    }

    try {
      isLoading = true;
      notifyListeners();

      user = await _authService.login(email: email, password: password);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Private fake login — only used in debug mode
  Future<void> _fakeLogin() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1)); // simulate network delay

    user = AppUser(
      uid: 'fake-uid-123',
      name: 'John Doe',
      email: 'john@example.com',
      profileImage: null,
    );
    // set to true to test preference page, 
    // false to test home
    isNewUser = true;

    isLoading = false;
    notifyListeners();
  }

  // Register
  Future<void> register(String name, String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      user = await _authService.register(name: name, email: email, password: password);
      isNewUser = true;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // reset isNewUser
  void completeOnboarding() {
    isNewUser = false;
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    try {
      isLoading = true;
      notifyListeners();

      if (!AppConfig.isDebug) {
        await _authService.logout(); // only call Firebase in production
      }

      user = null;        // Clear user
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Forget password
  Future<void> resetPassword(String email) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      await _authService.resetPassword(email);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}