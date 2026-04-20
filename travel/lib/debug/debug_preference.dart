import 'package:flutter/material.dart'; // UI
import 'package:provider/provider.dart';
import 'package:travel/service/preference_service.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';
import 'package:travel/views/preferences/preference_page.dart'; // connect UI to ViewModel

// need to initalize firebase 
void main() {
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