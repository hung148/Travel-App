import 'package:flutter/material.dart';
// use to talk to PreferenceViewModel
import 'package:provider/provider.dart'; 
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';
import 'package:travel/widgets/chips/chips.dart';

// this is statefulWidget because it respond to user input
class PreferencePage extends StatefulWidget { 
    // need ownerId to know whose preferences to load
    final String ownerId; 

    // constructor
    const PreferencePage({super.key, required this.ownerId}); 

    // This create a state object that holds the screen's 
    // changing values.
    @override
    State<PreferencePage> createState() 
      => _PreferencePageState();
    }

class _PreferencePageState extends State<PreferencePage> {

    // Store user's selection
    String? _experienceType;
    String? _activityLevel;
    String? _spendingStyle;

    // initialize 
    bool _hasInitialized = false;

    // Track which page is currently visible
    int _currentPage = 0;

    // chip labels for each section
    final _experienceOptions = [
      'Nature', 
      'History', 
      'Food', 
      'Mix'
    ];
    final _activityOptions = [
      'Relaxed', 
      'Moderate', 
      'Very Active'
    ];
    final _spendingOptions = [
      'Budget', 
      'Normal', 
      'Luxury'
    ];

    // total question
    final _totalQuestion = 3;

    // the "remote control" for PageView
    final _pageController = PageController(); 
    
    // when screen loads this is called once 
    @override
    void initState() {
        super.initState();

        // this wait until the first frame is drawn
        // then call the ViewModel loadPreference(ownerId)
        WidgetsBinding.instance.addPostFrameCallback((_) {
            // Call functions without rebuild UI
            context.read<PreferenceViewmodel>()
              .loadPreferences(
                widget.ownerId
            );
        });
    }

    // Clean up controller when the screen is destroyed
    @override
    void dispose() {
      // prevents memory leak
      _pageController.dispose();
      super.dispose();
    }

    // When preferences load from Firestore, pre-fill the 
    // selections
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

    // fills the progress bar: 
    double get _progressValue 
      => (_currentPage + 1) / _totalQuestion;

    // is THIS specific page's question answered ?
    bool _isAnswered(int page) => switch (page) {
      0 => _experienceType != null,
      1 => _activityLevel != null,
      _ => _spendingStyle != null,
    };

    // this function is called whenvever Flutter needs to redraw 
    // this screen
    @override
    Widget build(BuildContext context) {
        // list map so itemBuilder can look up the label
        // and options by index i
        final pages = [
        {
          'label': 'What do you enjoy?', 
          'options': _experienceOptions
        },
        {
          'label': 'Trip pace',          
          'options': _activityOptions
        },
        {
          'label': 'Budget preference',  
          'options': _spendingOptions
        },
      ];

        // basic structure
        return Scaffold(
          // Top bar of the screen
          appBar: AppBar(
            title: const Text('Travel Preferences'),
            // bottom parameter requires a widget that knows
            // its own height.
            bottom: PreferredSize(
              // PreferredSize wraps any widget and tells
              // AppBar that it is 8px tall.
              preferredSize: const Size.fromHeight(8),
              // watches _progressValue. Every time it changes,
              // it smoothly animates from the old value to 
              // the new one. You get the animated value as
              // value in the builder
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progressValue), 
                duration: const Duration(microseconds: 400),
                curve: Curves.easeInOut, 
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Consumer is a widget from the Provider package
          // It listens to changes in PreferenceViewModel
          // Whenever the ViewModel notifies listeners (e.g.,
          // after loading or saving), the UI inside this
          // Consumer rebuilds.
          // This ensures the screen reacts to async Firestore
          // loads and save events.
          body: Consumer<PreferenceViewmodel>(
              // context -> Flutter context
              // vm -> the current instance of 
              // PreferenceViewmodel
              // _ -> the child parameter (unused here)
              builder: (context, vm, _) {
                // After ViewModel loads preferences from 
                // Firestore, this method ensures the chips
                // are pre-selected with saved values.
                _syncFromViewModel(vm.preference);

                // If the ViewModel is currently loading
                // that is fetching from Firestore
                if (vm.isLoading) {
                    // Show a loading spinner
                    // Stop building the rest of the UI
                    return const Center(
                      child: CircularProgressIndicator()
                    );
                }

                // When saving finishes successfully
                if (vm.savedSuccessfully) {
                    // addPostFrameCallback ensures
                    // No setState or UI changes happen during
                    // build phase
                    WidgetsBinding
                      .instance
                      .addPostFrameCallback((_) {
                        // A SnackBar is shown after the frame
                        // to avoid calling ScaffoldMessenger 
                        // during build
                        ScaffoldMessenger
                        .of(context)
                        .showSnackBar(
                          const SnackBar(
                            content: Text('Preferences saved!')
                          ),
                        );
                    });
                }
                
                // The main UI is returned here
                return PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() {
                    _currentPage = i;
                  }),
                  itemCount: _totalQuestion,
                  itemBuilder: (context, i) {
                    final isLast = i == (_totalQuestion - 1);
                
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: 
                          CrossAxisAlignment.start,
                        children: [
                
                          // Question
                          ChipSection(
                            label: pages[i]['label'] as String,
                            options: 
                              pages[i]['options'] as 
                                List<String>,
                            selected: switch (i) {
                              0 => _experienceType,
                              1 => _activityLevel,
                              _ => _spendingStyle,
                            },
                            onSelected: (v) => setState(() {
                              if (i == 0) 
                                {_experienceType = v;}
                              else if (i == 1) 
                                {_activityLevel = v;}
                              else 
                                {_spendingStyle = v;}
                            }),
                          ),
                
                          // spacing
                          const Spacer(),
                
                          // Next or Save button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isAnswered(i)
                                ? () {
                                  if (isLast) {
                                    _save(vm);
                                  } else {
                                    _pageController.nextPage(
                                      duration: 
                                        const Duration(
                                          milliseconds: 400,
                                        ), 
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                } : null, 
                              child: Padding(
                                padding: const EdgeInsets
                                  .symmetric(vertical: 14),
                                child: Text(
                                  isLast 
                                  ? 'Save preferences' 
                                  : 'Next',  // label changes
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ); 
                  },
                );
              },
          ),
        );
    }
}

