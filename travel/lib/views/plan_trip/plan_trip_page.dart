import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/place_role.dart';
import '../../models/planner_result.dart';
import '../../models/preference/preferences.dart';
import '../../models/planner_validation.dart';
import '../../models/travel_place.dart';
import '../../models/trip/trip.dart';
import '../../service/map_service.dart';
import '../../service/planner/destination_place_service.dart';
import '../../service/planner/mock_places.dart';
import '../../service/planner/place_role_classifier.dart';
import '../../service/planner/place_scoring_service.dart';
import '../../service/planner/plan_refinement_service.dart';
import '../../service/planner/travel_planner_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/preference_viewmodel.dart';
import 'ai_chat_widget.dart';
import '../preferences/preference_page.dart';

class PlanTripPage extends StatefulWidget {
  const PlanTripPage({super.key});

  @override
  State<PlanTripPage> createState() => _PlanTripPageState();
}

class _PlanTripPageState extends State<PlanTripPage> {
  final destinationController = TextEditingController(text: 'Tokyo, Japan');
  final budgetController = TextEditingController(text: '2000');

  final TravelPlannerService _planner = TravelPlannerService(
    placeScoringService: PlaceScoringService(),
  );
  final PlanRefinementService _refinementService =
      const PlanRefinementService();
  late final DestinationPlaceService? _destinationPlaceService =
      AppConfig.hasGoogleMapsApiKey
      ? DestinationPlaceService(
          mapService: MapService(apiKey: AppConfig.googleMapsApiKey),
        )
      : null;

  DateTimeRange? dates;
  int travelers = 2;
  bool planGenerated = false;
  bool isGenerating = false;
  bool isLoadingPreference = true;
  String selectedPlan = 'Balanced';
  String placeDataSource = AppConfig.hasGoogleMapsApiKey
      ? 'Google Places ready'
      : 'Mock Tokyo data • Google API key not configured';
  Preference? savedPreference;
  String? preferenceError;
  PlannerResult? plannerResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreference());
  }

  @override
  void dispose() {
    destinationController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDateRange: dates,
    );
    if (selected != null && mounted) {
      setState(() => dates = selected);
    }
  }

  String _dateLabel() {
    if (dates == null) return 'Choose travel dates';
    String format(DateTime date) => '${date.month}/${date.day}/${date.year}';
    return '${format(dates!.start)} – ${format(dates!.end)}';
  }

  String _activityLevelForPlan(String plan) {
    switch (plan) {
      case 'Relaxed':
        return 'Relaxed';
      case 'Explorer':
        return 'Very Active';
      default:
        return 'Moderate';
    }
  }

  String _planForActivityLevel(String activityLevel) {
    switch (activityLevel.toLowerCase().trim()) {
      case 'relaxed':
        return 'Relaxed';
      case 'very active':
      case 'explorer':
        return 'Explorer';
      default:
        return 'Balanced';
    }
  }

  Future<void> _loadPreference() async {
    final ownerId = context.read<AuthViewModel>().user?.uid;

    if (ownerId == null) {
      if (!mounted) return;
      setState(() {
        isLoadingPreference = false;
        preferenceError = 'Sign in to load your travel preferences.';
      });
      return;
    }

    setState(() {
      isLoadingPreference = true;
      preferenceError = null;
    });

    final viewModel = context.read<PreferenceViewmodel>();
    await viewModel.loadPreferences(ownerId);

    if (!mounted) return;

    final preference = viewModel.preference;
    setState(() {
      isLoadingPreference = false;
      savedPreference = preference;
      preferenceError = preference == null
          ? viewModel.errorMessage ?? 'No saved preference was found.'
          : null;
      if (preference != null) {
        selectedPlan = _planForActivityLevel(preference.activityLevel);
      }
    });
  }

  Preference? _preferenceForSelectedPlan() {
    return savedPreference?.copyWith(
      activityLevel: _activityLevelForPlan(selectedPlan),
    );
  }

  Future<void> _generatePlan() async {
    final preference = _preferenceForSelectedPlan();
    if (preference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Load or save your travel preferences first.'),
        ),
      );
      return;
    }

    final destination = destinationController.text.trim();
    final budget = double.tryParse(budgetController.text.trim());

    if (destination.isEmpty || budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a destination and valid budget first.'),
        ),
      );
      return;
    }

    setState(() => isGenerating = true);

    try {
      var candidatePlaces = List<TravelPlace>.of(mockTokyoPlaces);
      var centerLatitude = 35.6762;
      var centerLongitude = 139.6503;
      var nextPlaceDataSource =
          'Mock Tokyo data • Google API key not configured';

      final destinationPlaceService = _destinationPlaceService;
      if (destinationPlaceService != null) {
        try {
          final destinationCandidates = await destinationPlaceService
              .loadForDestination(destination);
          if (destinationCandidates.places.isNotEmpty) {
            candidatePlaces = destinationCandidates.places;
            centerLatitude = destinationCandidates.center.latitude;
            centerLongitude = destinationCandidates.center.longitude;
            nextPlaceDataSource =
                'Live Google Places • ${candidatePlaces.length} candidates';
          } else {
            nextPlaceDataSource =
                'Mock Tokyo data • Google returned no candidates';
          }
        } catch (error) {
          nextPlaceDataSource = 'Mock Tokyo data • Google Places unavailable';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not load Google Places. Using mock data. $error',
                ),
              ),
            );
          }
        }
      }

      final dayCount = dates == null
          ? 3
          : dates!.end.difference(dates!.start).inDays + 1;

      final trip = Trip(
        id: 'ui_test_trip',
        ownerId: preference.ownerId,
        destination: destination,
        budget: budget,
        days: dayCount,
        status: 'draft',
        startDate: dates?.start,
        endDate: dates?.end,
      );

      final result = _planner.generatePlan(
        trip: trip,
        preference: preference,
        candidatePlaces: candidatePlaces,
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
      );

      if (!mounted) return;

      setState(() {
        plannerResult = result;
        planGenerated = true;
        placeDataSource = nextPlaceDataSource;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not generate plan: $e')));
    } finally {
      if (mounted) {
        setState(() => isGenerating = false);
      }
    }
  }

  void _selectPlan(String value) {
    setState(() => selectedPlan = value);

    if (planGenerated) {
      _generatePlan();
    }
  }

  Future<String> _refinePlan(String instruction) async {
    final current = plannerResult;
    if (current == null) {
      return 'Generate a plan first, then ask me to refine it.';
    }
    final lower = instruction.toLowerCase();
    final budgetMatch = RegExp(
      r'(?:under|budget(?:\s+of)?)\s*\$?\s*([0-9]+(?:\.[0-9]+)?)',
    ).firstMatch(lower);
    if (budgetMatch != null || lower.contains('cheaper')) {
      final currentBudget = double.tryParse(budgetController.text.trim());
      final requestedBudget = budgetMatch == null
          ? (currentBudget == null ? null : currentBudget * 0.85)
          : double.tryParse(budgetMatch.group(1)!);
      if (requestedBudget == null || requestedBudget <= 0) {
        return 'I could not determine a valid total budget from that request.';
      }
      budgetController.text = requestedBudget.toStringAsFixed(0);
      await _generatePlan();
      final regenerated = plannerResult;
      if (regenerated == null || !regenerated.validation.isValid) {
        return 'I could not create a valid plan at that budget.';
      }
      return 'Regenerated the itinerary with a total budget of '
          '\$${requestedBudget.toStringAsFixed(0)}. Validation passed.';
    }
    final refinement = _refinementService.refine(
      currentPlan: current,
      instruction: instruction,
    );
    if (refinement.changed && refinement.plan.validation.isValid && mounted) {
      setState(() => plannerResult = refinement.plan);
    }
    return refinement.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          children: [
            Icon(Icons.travel_explore),
            SizedBox(width: 10),
            Text('Plan a trip'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draft saved locally for this UI demo.'),
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save draft'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1000;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Build your next trip',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choose the basics, generate a plan, then negotiate changes with the AI planner.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.62),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (desktop)
                          FilledButton.icon(
                            onPressed: isGenerating || savedPreference == null
                                ? null
                                : _generatePlan,
                            icon: isGenerating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded),
                            label: Text(
                              isGenerating
                                  ? 'Generating...'
                                  : planGenerated
                                  ? 'Regenerate plan'
                                  : 'Generate plan',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _PreferenceStatusCard(
                      preference: savedPreference,
                      isLoading: isLoadingPreference,
                      error: preferenceError,
                      selectedPlan: selectedPlan,
                      onRetry: _loadPreference,
                      onEdit: () async {
                        final ownerId = savedPreference?.ownerId;
                        if (ownerId == null) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PreferencePage(
                              ownerId: ownerId,
                              returnOnSave: true,
                            ),
                          ),
                        );
                        if (mounted) await _loadPreference();
                      },
                    ),
                    const SizedBox(height: 20),
                    _TripSetupCard(
                      destinationController: destinationController,
                      budgetController: budgetController,
                      dateLabel: _dateLabel(),
                      travelers: travelers,
                      onPickDates: _pickDates,
                      onTravelersChanged: (value) =>
                          setState(() => travelers = value),
                    ),
                    if (!desktop) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isGenerating || savedPreference == null
                              ? null
                              : _generatePlan,
                          icon: isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            isGenerating
                                ? 'Generating...'
                                : planGenerated
                                ? 'Regenerate plan'
                                : 'Generate plan',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(flex: 3, child: _MapPlaceholder()),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 430,
                              child: AiChatWidget(onRefinePlan: _refinePlan),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      const _MapPlaceholder(),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 430,
                        child: AiChatWidget(onRefinePlan: _refinePlan),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _PlanOptions(
                      selectedPlan: selectedPlan,
                      enabled: planGenerated,
                      onSelected: _selectPlan,
                    ),
                    const SizedBox(height: 20),
                    _PlanPreview(
                      generated: planGenerated,
                      selectedPlan: selectedPlan,
                      destination: destinationController.text.trim().isEmpty
                          ? 'your destination'
                          : destinationController.text.trim(),
                      result: plannerResult,
                      placeDataSource: placeDataSource,
                      onGenerate: _generatePlan,
                      onReview: () => Navigator.pushNamed(context, '/summary'),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreferenceStatusCard extends StatelessWidget {
  final Preference? preference;
  final bool isLoading;
  final String? error;
  final String selectedPlan;
  final VoidCallback onRetry;
  final VoidCallback onEdit;

  const _PreferenceStatusCard({
    required this.preference,
    required this.isLoading,
    required this.error,
    required this.selectedPlan,
    required this.onRetry,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _Panel(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Text('Loading your saved travel preferences...'),
          ],
        ),
      );
    }

    if (preference == null) {
      return _Panel(
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(error ?? 'No saved travel preference was found.'),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onEdit,
              child: const Text('Set preferences'),
            ),
          ],
        ),
      );
    }

    final preferenceLabels = <String>{
      ...preference!.experienceType,
      ...preference!.interests,
    };

    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.person_pin_circle_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Planning with your saved preferences',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  '$selectedPlan pace • ${preference!.spendingStyle} spending',
                ),
                if (preferenceLabels.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: preferenceLabels
                        .map((label) => Chip(label: Text(label)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _TripSetupCard extends StatelessWidget {
  final TextEditingController destinationController;
  final TextEditingController budgetController;
  final String dateLabel;
  final int travelers;
  final VoidCallback onPickDates;
  final ValueChanged<int> onTravelersChanged;

  const _TripSetupCard({
    required this.destinationController,
    required this.budgetController,
    required this.dateLabel,
    required this.travelers,
    required this.onPickDates,
    required this.onTravelersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final fields = [
            _LabeledField(
              label: 'Destination',
              child: TextField(
                controller: destinationController,
                decoration: const InputDecoration(
                  hintText: 'Tokyo, Japan',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ),
            _LabeledField(
              label: 'Travel dates',
              child: OutlinedButton.icon(
                onPressed: onPickDates,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(dateLabel),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            _LabeledField(
              label: 'Total budget',
              child: TextField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '2,500',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
            ),
            _LabeledField(
              label: 'Travelers',
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: travelers > 1
                          ? () => onTravelersChanged(travelers - 1)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '$travelers',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onTravelersChanged(travelers + 1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ];

          if (!wide) {
            return Column(
              children: fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: field,
                    ),
                  )
                  .toList(),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                Expanded(child: fields[i]),
                if (i != fields.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 430,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.06),
                  child: CustomPaint(painter: _MapGridPainter()),
                ),
              ),
              const Positioned(
                left: 110,
                top: 135,
                child: _MapPin(number: '1'),
              ),
              const Positioned(
                left: 245,
                top: 225,
                child: _MapPin(number: '2'),
              ),
              const Positioned(
                right: 145,
                top: 115,
                child: _MapPin(number: '3'),
              ),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 52),
                    SizedBox(height: 12),
                    Text(
                      'Google Map Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Real Google Maps data will replace this placeholder'),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Chip(
                  avatar: const Icon(Icons.location_searching, size: 18),
                  label: const Text('Destination map'),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String number;
  const _MapPin({required this.number});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      child: Text(number, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _PlanOptions extends StatelessWidget {
  final String selectedPlan;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const _PlanOptions({
    required this.selectedPlan,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final plans = [
      (
        'Relaxed',
        '3 stops • 5 hr',
        'Nearby favorites • more free time',
        Icons.spa_outlined,
      ),
      (
        'Balanced',
        '4 stops • 7 hr',
        'Balanced variety, value, and travel',
        Icons.balance_outlined,
      ),
      (
        'Explorer',
        '6 stops • 9.5 hr',
        'More variety • wider travel range',
        Icons.explore_outlined,
      ),
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded),
              const SizedBox(width: 10),
              const Text(
                'Choose a plan style',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  enabled
                      ? 'Changes regenerate the algorithm'
                      : 'Generate a plan first',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: plans.map((plan) {
                  final selected = selectedPlan == plan.$1;
                  return SizedBox(
                    width: cardWidth,
                    child: InkWell(
                      onTap: enabled ? () => onSelected(plan.$1) : null,
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: selected && enabled
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.08)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected && enabled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.45),
                            width: selected && enabled ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              plan.$4,
                              color: enabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.$1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    plan.$3,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              plan.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlanPreview extends StatelessWidget {
  final bool generated;
  final String selectedPlan;
  final String destination;
  final PlannerResult? result;
  final String placeDataSource;
  final VoidCallback onGenerate;
  final VoidCallback onReview;

  const _PlanPreview({
    required this.generated,
    required this.selectedPlan,
    required this.destination,
    required this.result,
    required this.placeDataSource,
    required this.onGenerate,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_timeline_outlined),
                  SizedBox(width: 10),
                  Text(
                    'Plan preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      placeDataSource.startsWith('Live')
                          ? Icons.cloud_done_outlined
                          : Icons.science_outlined,
                      size: 18,
                    ),
                    label: Text(placeDataSource),
                  ),
                  Chip(
                    label: Text(
                      generated
                          ? '$selectedPlan plan'
                          : 'No plan generated yet',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!generated || result == null) ...[
            Text(
              'Generate a plan to preview a day-by-day itinerary for $destination.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate algorithm plan'),
            ),
          ] else ...[
            _RankingSummary(result: result!),
            const SizedBox(height: 18),
            _BudgetAllocationSummary(result: result!),
            const SizedBox(height: 12),
            _PlannerValidationSummary(validation: result!.validation),
            const Divider(height: 32),
            if (result!.days.every((day) => day.places.isEmpty))
              const Text(
                'No places fit the current activity budget. Try increasing the budget.',
              )
            else
              for (int i = 0; i < result!.days.length; i++) ...[
                _GeneratedDayPreview(
                  day: result!.days[i],
                  targetMinutes: result!.profile.targetMinutesPerDay,
                  restMinutes: result!.profile.restMinutesPerDay,
                ),
                if (i != result!.days.length - 1) const Divider(height: 32),
              ],
            const Divider(height: 32),
            _TotalExpenseSummary(result: result!),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: result!.validation.isValid ? onReview : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Review final plan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlannerValidationSummary extends StatelessWidget {
  final PlannerValidationResult validation;

  const _PlannerValidationSummary({required this.validation});

  @override
  Widget build(BuildContext context) {
    final hasErrors = validation.errors.isNotEmpty;
    final hasWarnings = validation.warnings.isNotEmpty;
    final issuesByDay = <int, List<PlannerValidationIssue>>{};
    final tripWideIssues = <PlannerValidationIssue>[];
    for (final issue in validation.issues) {
      final dayNumber = issue.dayNumber;
      if (dayNumber == null) {
        tripWideIssues.add(issue);
      } else {
        issuesByDay.putIfAbsent(dayNumber, () => []).add(issue);
      }
    }
    final dayNumbers = issuesByDay.keys.toList()..sort();
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = hasErrors
        ? colorScheme.errorContainer
        : hasWarnings
        ? colorScheme.tertiaryContainer
        : colorScheme.primaryContainer;
    final foregroundColor = hasErrors
        ? colorScheme.onErrorContainer
        : hasWarnings
        ? colorScheme.onTertiaryContainer
        : colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasErrors
                ? Icons.error_outline_rounded
                : hasWarnings
                ? Icons.warning_amber_rounded
                : Icons.verified_outlined,
            color: foregroundColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasErrors
                      ? 'Planner validation failed'
                      : hasWarnings
                      ? 'Planner validation passed with warnings'
                      : 'Planner validation passed',
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (validation.issues.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final dayNumber in dayNumbers) ...[
                    _ValidationIssueGroup(
                      title: 'Day $dayNumber',
                      issues: issuesByDay[dayNumber]!,
                      foregroundColor: foregroundColor,
                      stripDayNumber: dayNumber,
                    ),
                    if (dayNumber != dayNumbers.last ||
                        tripWideIssues.isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  if (tripWideIssues.isNotEmpty)
                    _ValidationIssueGroup(
                      title: 'Whole trip',
                      issues: tripWideIssues,
                      foregroundColor: foregroundColor,
                    ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'No duplicates or budget, time, place-count, empty-day, or total-cost problems found.',
                    style: TextStyle(color: foregroundColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationIssueGroup extends StatelessWidget {
  final String title;
  final List<PlannerValidationIssue> issues;
  final Color foregroundColor;
  final int? stripDayNumber;

  const _ValidationIssueGroup({
    required this.title,
    required this.issues,
    required this.foregroundColor,
    this.stripDayNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: foregroundColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.severity == PlannerValidationSeverity.error
                        ? Icons.error_outline_rounded
                        : Icons.warning_amber_rounded,
                    color: foregroundColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _withoutDayPrefix(issue.message),
                      style: TextStyle(color: foregroundColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _withoutDayPrefix(String message) {
    final dayNumber = stripDayNumber;
    if (dayNumber == null) return message;
    return message.replaceFirst(RegExp('^Day $dayNumber\\s+'), '');
  }
}

class _BudgetAllocationSummary extends StatelessWidget {
  final PlannerResult result;

  const _BudgetAllocationSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final allocation = result.budgetAllocation;
    final categories = [
      ('Accommodation', allocation.accommodation, Icons.hotel_outlined),
      ('Food', allocation.food, Icons.restaurant_outlined),
      (
        'Transportation',
        allocation.transportation,
        Icons.directions_transit_outlined,
      ),
      ('Activities', allocation.activities, Icons.local_activity_outlined),
      ('Buffer', allocation.buffer, Icons.savings_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined),
              const SizedBox(width: 10),
              Text(
                'Budget allocation • \$${allocation.total.toStringAsFixed(0)} total',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories
                .map(
                  (category) => Chip(
                    avatar: Icon(category.$3, size: 18),
                    label: Text(
                      '${category.$1}: \$${category.$2.toStringAsFixed(0)}',
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Attractions use only the activities allocation '
            '(\$${allocation.dailyActivitiesBudget(result.days.length).toStringAsFixed(0)} per day).',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalExpenseSummary extends StatelessWidget {
  final PlannerResult result;

  const _TotalExpenseSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.payments_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Total estimated activity expense',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '\$${result.totalEstimatedCost.toStringAsFixed(0)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingSummary extends StatelessWidget {
  final PlannerResult result;

  const _RankingSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final top = result.rankedPlaces.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top ranked places',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top
              .map(
                (item) => Chip(
                  avatar: CircleAvatar(
                    child: Text(item.totalScore.toStringAsFixed(0)),
                  ),
                  label: Text(item.place.name),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _GeneratedDayPreview extends StatelessWidget {
  final PlannerDay day;
  final int targetMinutes;
  final int restMinutes;

  const _GeneratedDayPreview({
    required this.day,
    required this.targetMinutes,
    required this.restMinutes,
  });

  @override
  Widget build(BuildContext context) {
    const roleClassifier = PlaceRoleClassifier();
    var diningIndex = 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Day ${day.dayNumber}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (day.places.isEmpty)
                const Text('Free day / no place selected')
              else
                for (
                  int stopIndex = 0;
                  stopIndex < day.places.length;
                  stopIndex++
                )
                  Builder(
                    builder: (context) {
                      final role = roleClassifier.classify(
                        day.places[stopIndex].place,
                      );
                      final roleLabel = role == PlaceRole.dining
                          ? switch (diningIndex++) {
                              0 => 'Lunch',
                              1 => 'Dinner',
                              final index => 'Extra food stop ${index + 1}',
                            }
                          : role.label;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              child: Text(
                                '${stopIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day.places[stopIndex].place.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$roleLabel • ${day.places[stopIndex].place.category} • '
                                    '${day.places[stopIndex].place.estimatedVisitMinutes} min • '
                                    'score ${day.places[stopIndex].totalScore.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.62),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '\$${day.places[stopIndex].place.estimatedCost.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              if (day.places.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.free_breakfast_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Rest / free time • ${_formatMinutes(restMinutes)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              Text(
                'Estimated activity cost: '
                '\$${day.estimatedCost.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Planned activity time: '
                '${_formatMinutes(day.estimatedVisitMinutes)} / '
                '${_formatMinutes(targetMinutes)} target',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.13)
      ..strokeWidth = 1;

    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
