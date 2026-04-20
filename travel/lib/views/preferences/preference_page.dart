import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // use to talk to PreferenceViewModel
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';

// this is statefulWidget because it respond to user input
class PreferencePage extends StatefulWidget { 
    final String ownerId; // need ownerId to know whose preferences to load
    const PreferencePage({super.key, required this.ownerId}); // constructor

    // This create a state object that holds the screen's changing values.
    @override
    State<PreferencePage> createState() => _PreferencePageState();
    }

class _PreferencePageState extends State<PreferencePage> {

    // Store user's selection
    String? _experienceType;
    String? _activityLevel;
    String? _spendingStyle;

    // initialize 
    bool _hasInitialized = false;

    // chip labels for each section
    final _experienceOptions = ['Nature', 'History', 'Food', 'Mix'];
    final _activityOptions = ['Relaxed', 'Moderate', 'Very Active'];
    final _spendingOptions = ['Budget', 'Normal', 'Luxury'];
    
    // when screen loads this is called once 
    @override
    void initState() {
        super.initState();

        // this wait until the first frame is drawn
        // then call the ViewModel loadPreference(ownerId)
        WidgetsBinding.instance.addPostFrameCallback((_) {
            // Call functions without rebuild UI
            context.read<PreferenceViewmodel>().loadPreferences(widget.ownerId);
        });
    }

    // When preferences load from Firestore, pre-fill the selections
    void _syncFromViewModel(Preference? pref) {
        if (pref == null || _hasInitialized) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
                _experienceType = pref.experienceType;
                _activityLevel = pref.activityLevel;
                _spendingStyle = pref.spendingStyle;
                _hasInitialized = true;
            });
        });
    }

    // this check if user has selected all required preferences
    // this behave like a variable
    bool get _isValid =>
        _experienceType != null &&
        _activityLevel != null &&
        _spendingStyle != null;

    // this save preference
    void _save(PreferenceViewmodel vm) {
        if (!_isValid) return;
        final pref = Preference(
            id: vm.preference?.id ?? widget.ownerId,
            ownerId: widget.ownerId,
            experienceType: _experienceType!,
            activityLevel: _activityLevel!,
            spendingStyle: _spendingStyle!,
            interests: vm.preference?.interests ?? [],
        );
        vm.savePreferences(pref);
    }

    // this function is called whenvever Flutter needs to redraw this screen
    @override
    Widget build(BuildContext context) {
        // basic structure
        return Scaffold(
        // Top bar of the screen
        appBar: AppBar(title: const Text('Travel Preferences')),
        body: Consumer<PreferenceViewmodel>(
            builder: (context, vm, _) {
            _syncFromViewModel(vm.preference);

            if (vm.isLoading) {
                return const Center(child: CircularProgressIndicator());
            }

            if (vm.savedSuccessfully) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preferences saved!')),
                );
                });
            }

            return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                    'Your travel style',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                    "We'll tailor recommendations just for you",
                    style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    if (vm.errorMessage != null && vm.errorMessage!.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                        vm.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        ),
                    ),

                    _ChipSection(
                    key: const Key('experience_section'),
                    label: 'What do you enjoy?',
                    options: _experienceOptions,
                    selected: _experienceType,
                    onSelected: (v) => setState(() => _experienceType = v),
                    ),
                    const SizedBox(height: 24),
                    _ChipSection(
                    key: const Key('activity_section'),
                    label: 'Trip pace',
                    options: _activityOptions,
                    selected: _activityLevel,
                    onSelected: (v) => setState(() => _activityLevel = v),
                    ),
                    const SizedBox(height: 24),
                    _ChipSection(
                    key: const Key('spending_section'),
                    label: 'Budget preference',
                    options: _spendingOptions,
                    selected: _spendingStyle,
                    onSelected: (v) => setState(() => _spendingStyle = v),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        key: const Key('save_button'),
                        onPressed: _isValid && !vm.isLoading ? () => _save(vm) : null,
                        child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                            'Save preferences',
                            style: TextStyle(fontSize: 16),
                        ),
                        ),
                    ),
                    ),
                ],
                ),
            );
            },
        ),
        );
    }
}

class _ChipSection extends StatelessWidget {
    final String label;
    final List<String> options;
    final String? selected;
    final ValueChanged<String> onSelected;

    const _ChipSection({
        super.key,
        required this.label,
        required this.options,
        required this.selected,
        required this.onSelected,
    });

    @override
    Widget build(BuildContext context) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                        return ChoiceChip(
                            key: Key('chip_$option'),
                            label: Text(option),
                            selected: option == selected,
                            onSelected: (_) => onSelected(option),
                        );
                    }).toList(),
                ),
            ],
        );
    }
}