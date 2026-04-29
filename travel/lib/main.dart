import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:travel/core/theme/app_theme.dart';

import 'package:travel/service/auth_service.dart';
import 'package:travel/service/preference_service.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';
import 'package:travel/views/auth/auth_gate.dart';
import 'package:travel/views/auth/forgot_password.dart';
import 'package:travel/views/auth/login.dart';
import 'package:travel/views/auth/sign_up.dart';
import 'package:travel/views/home/home_page.dart';
import 'package:travel/views/preferences/preference_page.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final preferenceService = PreferenceService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(authService),
        ),
        ChangeNotifierProvider(
          create: (_) => PreferenceViewmodel(preferenceService),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Travel App',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const AuthGate(),
        routes: {
          '/signup': (_) => const SignupPage(),
          '/forgot-password': (_) => const ForgotPasswordPage(),
          '/home': (_) => const HomePage(),
        },
      ),
    );
  }
}
