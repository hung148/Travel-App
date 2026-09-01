import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/views/auth/login.dart';
import 'package:travel/views/preferences/preference_page.dart';
import 'package:travel/views/profile/profile_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    if (authViewModel.isRestoringSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authViewModel.user != null) {
      if (authViewModel.isNewUser) {
        return PreferencePage(ownerId: authViewModel.user!.uid);
      }
      return const ProfilePage();
    }

    return const LoginPage();
  }
}
