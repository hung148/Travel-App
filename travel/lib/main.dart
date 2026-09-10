import 'views/existing_plan/existing_plan_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:travel/core/theme/app_theme.dart';

import 'package:travel/service/account_deletion_service.dart';
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
import 'package:travel/views/plan_trip/plan_trip_page.dart';
import 'package:travel/views/summary/summary_page.dart';

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

const environment = String.fromEnvironment('ENV', defaultValue: 'dev');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

Future<void> _initializeFirebase() => Firebase.initializeApp(
  options: environment == 'prod'
      ? prod.DefaultFirebaseOptions.currentPlatform
      : dev.DefaultFirebaseOptions.currentPlatform,
);

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _initialization = _initializeFirebase();

  void _retry() {
    setState(() => _initialization = _initializeFirebase());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NghienTravel',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.error == null) {
            return const MyApp();
          }

          if (snapshot.hasError) {
            return _StartupError(error: snapshot.error!, onRetry: _retry);
          }

          return const _StartupLoading();
        },
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Preparing your journey',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text(
              'Connecting securely…',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: colors.error),
                  const SizedBox(height: 18),
                  Text(
                    'The app could not connect',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Check your internet connection and Firebase configuration, then try again.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error.toString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final accountDeletionService = AccountDeletionService();
    final preferenceService = PreferenceService();
    final tripService = TripService();
    final itineraryService = ItineraryService();
    final feedbackService = FeedbackService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(authService, accountDeletionService),
        ),
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
        title: 'NghienTravel',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        home: const AuthGate(),
        routes: {
          '/signup': (_) => const SignupPage(),
          '/forgot-password': (_) => const ForgotPasswordPage(),
          // No '/profile' route on purpose. ProfilePage is rendered by
          // AuthGate, never pushed: a pushed copy would sit above AuthGate
          // (or replace it) and keep showing after sign-out, because it is
          // AuthGate alone that reacts to the user going away.
          '/plan-trip': (_) => const PlanTripPage(),
          '/existing-plan': (_) => const ExistingPlanPage(),
          '/summary': (_) => const SummaryPage(),
        },
      ),
    );
  }
}
