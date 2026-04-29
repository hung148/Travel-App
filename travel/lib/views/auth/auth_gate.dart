// This widget watches user and automatically shows the right screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/views/auth/login.dart';
import 'package:travel/views/home/home_page.dart';
import 'package:travel/views/preferences/preference_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = 
      context.watch<AuthViewModel>();
    
    // Show loading spinner while processing
    if (authViewModel.isLoading) {
      return const Scaffold(
        body: Center(child: 
          CircularProgressIndicator()
        ),
      );
    }

    // Route based on login state
    if (authViewModel.user != null) {
      if (authViewModel.isNewUser) {
        return PreferencePage(
          ownerId: authViewModel.user!.uid,
        );
      } 
      return const HomePage();
    }

    return const LoginPage();
  }
}