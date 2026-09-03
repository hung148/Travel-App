import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:travel/core/theme/app_theme.dart';

import 'package:travel/service/auth_service.dart';
import 'package:travel/service/preference_service.dart';
import 'package:travel/service/trip_service.dart';
import 'package:travel/service/itinerary_service.dart';
import 'package:travel/service/feedback_service.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';
import 'package:travel/viewmodels/trip_viewmodel.dart';
import 'package:travel/views/auth/auth_gate.dart';
import 'package:travel/views/auth/forgot_password.dart';
import 'package:travel/views/auth/sign_up.dart';
import 'package:travel/views/profile/profile_page.dart';
import 'package:travel/views/plan_trip/plan_trip_page.dart';
import 'package:travel/views/summary/summary_page.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final preferenceService = PreferenceService();
    final tripService = TripService();
    final itineraryService = ItineraryService();
    final feedbackService = FeedbackService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel(authService)),
        ChangeNotifierProvider(
          create: (_) => PreferenceViewmodel(preferenceService),
        ),
        ChangeNotifierProvider(
          create: (_) => TripViewModel(
            tripService: tripService,
            itineraryService: itineraryService,
            preferencesService: preferenceService,
            feedbackService: feedbackService,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Travel App',
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final currentScale = mediaQuery.textScaler.scale(1);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(currentScale * 1.08),
            ),
            child: child!,
          );
        },
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        home: const AuthGate(),
        routes: {
          '/signup': (_) => const SignupPage(),
          '/forgot-password': (_) => const ForgotPasswordPage(),
          '/profile': (_) => const ProfilePage(),
          '/plan-trip': (_) => const PlanTripPage(),
          '/summary': (_) => const SummaryPage(),
        },
      ),
    );
  }
}
