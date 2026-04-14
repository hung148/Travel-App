import 'package:flutter/material.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;

  bool isLoading = false;
  String? errorMessage;
  AppUser? user;

  AuthViewModel(this._authService);

  // Login
  Future<void> login(String email, String password) async {
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

  // Register
  Future<void> register(String name, String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      user = await _authService.register(name: name, email: email, password: password);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      isLoading = true;
      notifyListeners();

      await _authService.logout();

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