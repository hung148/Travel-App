import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:travel/service/preference_service.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';
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
    final preferenceService = PreferenceService();

    // crete and shares ViewModel across widget
    return ChangeNotifierProvider(
      create: (_) => PreferenceViewmodel(preferenceService),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PreferencePage(ownerId: "test-user"),
      ),
    );
  }
}
