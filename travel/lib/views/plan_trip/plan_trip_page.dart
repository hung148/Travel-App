import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../core/utils/money.dart';
import '../../models/cost_breakdown.dart';
import '../../models/cost_estimate.dart';
import '../../models/planner_result.dart';
import '../../models/budget_allocation.dart';
import '../../models/planner_profile.dart';
import '../../models/plan_refinement_result.dart';
import '../../models/ai/trip_ai_command.dart';
import '../../models/hotel_stay.dart';
import '../../models/hotel_selections.dart';
import '../../models/preference/preferences.dart';
import '../../models/planner_validation.dart';
import '../../models/score_place.dart';
import '../../models/travel_place.dart';
import '../../models/trip/trip.dart';
import '../../models/trip/trip_segment.dart';
import '../../service/map_service.dart';
import '../../service/ai/trip_ai_service.dart';
import '../../service/ai/stop_name_matcher.dart';
import '../../service/planner/destination_place_service.dart';
import '../../service/planner/mock_places.dart';
import '../../service/planner/daily_time_schedule_service.dart';
import '../../service/planner/place_scoring_service.dart';
import '../../service/planner/plan_refinement_service.dart';
import '../../service/planner/planner_validation_service.dart';
import '../../service/currency_rate_service.dart';
import '../../service/planner/travel_planner_service.dart';
import '../../widgets/cost_breakdown_page.dart';
import '../../widgets/inputs/currency_field.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/preference_viewmodel.dart';
import '../../viewmodels/trip_viewmodel.dart';
import '../../widgets/place_photo.dart';
import 'ai_chat_widget.dart';
import '../preferences/preference_page.dart';
import '../summary/summary_page.dart';
import 'models/destination_draft.dart';
import 'models/destination_date_availability.dart';
import 'models/map_search_area.dart';
import '../../models/trip/travel_leg.dart';
import 'models/travel_time_estimator.dart';
import 'widgets/add_destination_dialog.dart';
import 'widgets/destination_selector.dart';
import 'widgets/map_area_picker_dialog.dart';

class PlanTripPage extends StatefulWidget {
  const PlanTripPage({super.key});

  @override
  State<PlanTripPage> createState() => _PlanTripPageState();
}

class _PlanTripPageState extends State<PlanTripPage> {
  final destinationController = TextEditingController();
  final tripTitleController = TextEditingController();
  final budgetController = TextEditingController(text: '2000');

  final TravelPlannerService _planner = TravelPlannerService(
    placeScoringService: PlaceScoringService(),
  );
  final PlanRefinementService _refinementService =
      const PlanRefinementService();
  late final MapService? _mapService = AppConfig.hasGoogleMapsApiKey
      ? MapService(apiKey: AppConfig.googleMapsApiKey)
      : null;
  late final DestinationPlaceService? _destinationPlaceService =
      _mapService != null
      ? DestinationPlaceService(mapService: _mapService)
      : null;

  DateTimeRange? dates;
  int travelers = 2;

  /// Currency the budget is typed in and the whole plan is priced in. This is
  /// the user's choice and nothing else changes it - not the destination, not
  /// what Google publishes locally.
  String currencyCode = Money.defaultCurrencyCode;

  /// Whether displayed amounts are per traveler or for the whole party.
  PriceDisplayMode priceDisplayMode = PriceDisplayMode.total;
  bool planGenerated = false;
  bool isGenerating = false;
  bool isLoadingPreference = true;
  String selectedPlan = 'Balanced';
  String placeDataSource = AppConfig.hasGoogleMapsApiKey
      ? 'Google Places ready'
      : 'Mock Tokyo data • Google API key not configured';
  Preference? savedPreference;
  String? preferenceError;

  /// The view model this page is subscribed to, kept so the listener can be
  /// detached again in [dispose].
  PreferenceViewmodel? _preferenceViewModel;

  /// The saved preference the itinerary on screen was actually built from.
  ///
  /// A save round-trips through Firestore and comes back as an equal but
  /// separate object; without this the reload would look like a second change
  /// and regenerate the plan twice.
  Preference? _generatedFromPreference;

  PlannerResult? plannerResult;
  List<HotelStay> hotelRecommendations = const [];
  HotelStay? selectedHotel;
  late final List<DestinationDraft> _destinations;

  final CurrencyRateService _currencyRates = CurrencyRateService();
  String _selectedDestinationId = '';
  final List<TravelLegDraft> _travelLegs = [];
  final TravelTimeEstimator _travelTimeEstimator = const TravelTimeEstimator();
  late final TripAiService _tripAiService = TripAiService(
    endpoint: AppConfig.aiAssistantUrl,
  );
  _AiUndoSnapshot? _aiUndoSnapshot;
  _PendingAiChoice? _pendingAiChoice;
  final StopNameMatcher _stopNameMatcher = const StopNameMatcher();

  @override
  void initState() {
    super.initState();
    _destinations = [];
    // Text fields do not rebuild the page on their own, so the button would
    // stay hidden until something else happened to trigger a frame.
    budgetController.addListener(_onSetupFieldChanged);
    destinationController.addListener(_onSetupFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSegmentsFromViewModel();
      await _loadPreference();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The view model is the single source of truth for the saved preference,
    // and it is a ChangeNotifier - so subscribing to it catches a change made
    // ANYWHERE (this page's Edit button, the Preferences tab, onboarding)
    // rather than only the one path that happened to call _loadPreference().
    final viewModel = context.read<PreferenceViewmodel>();
    if (identical(viewModel, _preferenceViewModel)) return;
    _preferenceViewModel?.removeListener(_onPreferenceChanged);
    _preferenceViewModel = viewModel..addListener(_onPreferenceChanged);
  }

  /// Applies a preference saved anywhere in the app, then rebuilds the
  /// itinerary to match it.
  ///
  /// Regenerating is the point. A plan that does not reflect the current
  /// preference is worse than no plan at all: the page says "Luxury spending"
  /// over a schedule built for Budget, and the only hint that the two
  /// disagree is a button the user has to know to press.
  void _onPreferenceChanged() {
    if (!mounted) return;

    final updated = _preferenceViewModel?.preference;
    if (updated == null || updated == savedPreference) return;

    final previous = savedPreference;
    setState(() {
      savedPreference = updated;
      isLoadingPreference = false;
      preferenceError = null;
      // Follow the saved activity level only when it is what changed.
      // Otherwise a spending-style edit would quietly discard the pace the
      // user picked on this page.
      if (previous == null || previous.activityLevel != updated.activityLevel) {
        selectedPlan = _planForActivityLevel(updated.activityLevel);
      }
    });

    // The very first load is not a change the user made, and there is nothing
    // on screen yet to bring back into line.
    if (previous == null || !planGenerated || isGenerating) return;
    if (updated == _generatedFromPreference) return;

    _regenerateForPreferenceChange();
  }

  Future<void> _regenerateForPreferenceChange() async {
    // _generatePlan reports anything missing through its own snackbars; if the
    // setup is still incomplete there is simply nothing to rebuild yet.
    if (_missingTripSetup.isNotEmpty) return;

    final before = plannerResult;
    await _generatePlan();
    if (!mounted || identical(plannerResult, before)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preferences updated — schedule regenerated.'),
      ),
    );
  }

  /// Everything the planner needs before it can produce anything.
  ///
  /// The generate button appears only once this holds, rather than sitting
  /// there greyed out - a disabled control tells you that you cannot proceed
  /// but not why, and the fields it depends on are right above it.
  /// What the form is still waiting for, named the way the fields are
  /// labelled, in the order they appear.
  ///
  /// The generate button is hidden rather than disabled, so without this the
  /// form gives no reason - you fill everything in and nothing appears, with
  /// no way to tell which check is unhappy.
  List<String> get _missingTripSetup {
    final budget = double.tryParse(budgetController.text.trim());

    return [
      if (savedPreference == null) 'your saved preferences',
      if (_destinations.isEmpty || destinationController.text.trim().isEmpty)
        'a destination',
      if (dates == null) 'travel dates',
      if (budget == null || budget <= 0) 'a total budget',
      if (!Money.isValidCode(currencyCode)) 'a currency',
      if (travelers < 1) 'at least one traveler',
    ];
  }

  bool get _isTripSetupComplete => _missingTripSetup.isEmpty;

  TripViewModel get _tripViewModel => context.read<TripViewModel>();

  Future<void> _loadSegmentsFromViewModel() async {
    final viewModel = _tripViewModel;
    if (viewModel.draftSegments.isEmpty) return;
    setState(() {
      _destinations
        ..clear()
        ..addAll(viewModel.draftSegments.map(_draftFromSegment));
      _travelLegs
        ..clear()
        ..addAll(viewModel.draftTravelLegs);
      _selectedDestinationId =
          viewModel.selectedSegmentId ?? _destinations.first.id;
      _loadDestination(_selectedDestination);
      tripTitleController.text = viewModel.currentTrip?.title ?? '';
    });
    await _reorderDestinationsAndTravelLegs();
  }

  DestinationDraft _draftFromSegment(TripSegment segment) {
    final hotel = segment.hotel;
    final mapSearchArea = segment.searchCenterLatitude == null ||
            segment.searchCenterLongitude == null ||
            segment.searchRadiusMeters == null
        ? null
        : MapSearchArea(
            latitude: segment.searchCenterLatitude!,
            longitude: segment.searchCenterLongitude!,
            radiusMeters: segment.searchRadiusMeters!,
          );
    return DestinationDraft(
      id: segment.id,
      destination: segment.destination,
      placeId: segment.destinationPlaceId,
      dates: DateTimeRange(start: segment.startDate, end: segment.endDate),
      budget: segment.allocatedBudget,
      selectedHotel: hotel == null
          ? null
          : HotelStay(
              id: hotel.placeId ?? 'saved-${segment.id}',
              name: hotel.name,
              address: hotel.address,
              latitude: hotel.latitude ?? 0,
              longitude: hotel.longitude ?? 0,
              rating: 0,
              nightlyRate: hotel.nightlyPrice ?? 0,
              nights: hotel.nights,
              rooms: 1,
              userProvided: true,
            ),
      savedDays: segment.days,
      placeDataSource: 'Saved trip',
      startTimeOverrides: segment.startTimeOverrides,
      undoDays: segment.undoDays,
      undoBudget: segment.undoBudget,
      undoStyle: segment.undoStyle,
      mapSearchArea: mapSearchArea,
    );
  }

  HotelSelection? _hotelSelection(HotelStay? hotel) => hotel == null
      ? null
      : HotelSelection(
          placeId: hotel.id,
          name: hotel.name,
          address: hotel.address,
          latitude: hotel.latitude,
          longitude: hotel.longitude,
          nightlyPrice: hotel.nightlyRate * hotel.rooms,
          nights: hotel.nights,
        );

  void _syncDraftToViewModel(DestinationDraft draft) {
    final range = draft.dates;
    if (range == null) return;
    final segment = TripSegment(
      id: draft.id,
      destination: draft.destination,
      destinationPlaceId: draft.placeId,
      startDate: range.start,
      endDate: range.end,
      allocatedBudget: draft.budget,
      hotel: _hotelSelection(draft.selectedHotel),
      days: draft.days.isNotEmpty
          ? draft.days
          : _tripViewModel.draftSegments
                    .where((item) => item.id == draft.id)
                    .firstOrNull
                    ?.days ??
                const [],
      startTimeOverrides:
          draft.plannerResult?.startTimeOverrides ?? draft.startTimeOverrides,
      undoDays: draft.undoDays,
      undoBudget: draft.undoBudget,
      undoStyle: draft.undoStyle,
      searchCenterLatitude: draft.mapSearchArea?.latitude,
      searchCenterLongitude: draft.mapSearchArea?.longitude,
      searchRadiusMeters: draft.mapSearchArea?.radiusMeters,
    );
    final exists = _tripViewModel.draftSegments.any(
      (item) => item.id == draft.id,
    );
    if (exists) {
      _tripViewModel.updateSegment(draft.id, segment);
    } else {
      _tripViewModel.addSegment(segment);
    }
  }

  DestinationDraft get _selectedDestination =>
      _destinations.firstWhere((item) => item.id == _selectedDestinationId);

  /// Null until the first destination is added.
  ///
  /// The dates, budget, currency and traveller fields are visible from the
  /// start now, so their handlers can fire while [_destinations] is still
  /// empty - and [_selectedDestination] throws in that state.
  DestinationDraft? get _selectedDestinationOrNull {
    for (final destination in _destinations) {
      if (destination.id == _selectedDestinationId) return destination;
    }
    return null;
  }

  void _persistSelectedDestination() {
    final selected = _selectedDestinationOrNull;
    if (selected == null) return;
    selected.destination = destinationController.text.trim().isEmpty
        ? selected.destination
        : destinationController.text.trim();
    selected.budget =
        double.tryParse(budgetController.text.trim()) ?? selected.budget;
    selected.dates = dates;
    selected.selectedPlan = selectedPlan;
    selected.plannerResult = plannerResult;
    selected.startTimeOverrides = plannerResult?.startTimeOverrides ?? const {};
    selected.hotelRecommendations = hotelRecommendations;
    selected.selectedHotel = selectedHotel;
    selected.placeDataSource = placeDataSource;
    _syncDraftToViewModel(selected);
  }

  void _loadDestination(DestinationDraft selected) {
    destinationController.text = selected.destination;
    budgetController.text = selected.budget.toStringAsFixed(
      selected.budget == selected.budget.roundToDouble() ? 0 : 2,
    );
    dates = selected.dates;
    selectedPlan = selected.selectedPlan;
    plannerResult = selected.plannerResult ??
        (selected.savedDays.isEmpty ? null : _resultFromSavedDestination(selected));
    hotelRecommendations = selected.hotelRecommendations;
    selectedHotel = selected.selectedHotel;
    placeDataSource = selected.placeDataSource;
    planGenerated = plannerResult != null;
    if (selected.undoDays.isNotEmpty && selected.plannerResult != null) {
      _aiUndoSnapshot = _AiUndoSnapshot(
        destinationId: selected.id,
        result: selected.plannerResult!.copyWith(days: selected.undoDays),
        budgetText: selected.undoBudget?.toStringAsFixed(0) ?? budgetController.text,
        selectedPlan: selected.undoStyle ?? selectedPlan,
        hotelRecommendations: List<HotelStay>.of(hotelRecommendations),
        selectedHotel: selectedHotel,
        placeDataSource: placeDataSource,
        planGenerated: true,
      );
    } else {
      _aiUndoSnapshot = null;
    }
  }

  PlannerResult _resultFromSavedDestination(DestinationDraft selected) {
    final days = selected.savedDays
        .map(
          (day) => PlannerDay(
            dayNumber: day.dayNumber,
            places: List<ScoredPlace>.of(day.places),
          ),
        )
        .toList();
    return PlannerResult(
      budgetAllocation: BudgetAllocation(
        total: selected.budget,
        accommodation: 0,
        // Day totals are per person; the allocation is the party's money.
        food: days.fold(
          0,
          (total, day) => total + day.estimatedFoodCostFor(travelers),
        ),
        transportation: 0,
        activities: days.fold(
          0,
          (total, day) => total + day.estimatedActivityCostFor(travelers),
        ),
        buffer: 0,
      ),
      validation: const PlannerValidationResult(issues: []),
      profile: PlannerProfile.balanced,
      rankedPlaces: days.expand((day) => day.places).toList(),
      days: days,
      startTimeOverrides: selected.startTimeOverrides,
      travelers: travelers,
      currencyCode: selected.currencyCode,
      priceDisplayMode: priceDisplayMode,
    );
  }

  void _selectDestination(String id) {
    if (id == _selectedDestinationId) return;
    setState(() {
      _persistSelectedDestination();
      _tripViewModel.selectSegment(id);
      _selectedDestinationId = id;
      _loadDestination(_selectedDestination);
    });
  }

  Future<void> _addDestination() async {
    final previous = _destinations.lastOrNull;
    if (previous != null) _persistSelectedDestination();
    final value = await showDialog<AddDestinationValue>(
      context: context,
      builder: (_) => const AddDestinationDialog(),
    );
    if (value == null || !mounted) return;
    final estimate = previous == null
        ? null
        : await _estimateIncomingTravel(
            previous.destination,
            value.destination,
            originPlaceId: previous.placeId,
            destinationPlaceId: value.placeId,
          );
    if (!mounted) return;
    final destination = DestinationDraft(
      id: 'destination-${DateTime.now().microsecondsSinceEpoch}',
      destination: value.destination,
      placeId: value.placeId,
      // The first destination inherits whatever the user filled in before
      // there was anything to attach it to - the fields are visible from the
      // start, so dates and a budget can legitimately be set first. Later
      // destinations start empty: each leg has its own dates, and they are not
      // allowed to overlap.
      dates: previous == null ? dates : null,
      budget: previous == null
          ? double.tryParse(budgetController.text.trim()) ?? 0
          : 0,
      selectedPlan: selectedPlan,
      placeDataSource: AppConfig.hasGoogleMapsApiKey
          ? 'Google Places ready'
          : 'Mock Tokyo data • Google API key not configured',
    );
    setState(() {
      _destinations.add(destination);
      if (estimate != null) {
        _travelLegs.add(
          TravelLegDraft(
            fromDestinationId: previous!.id,
            toDestinationId: destination.id,
            estimate: estimate,
          ),
        );
      }
      _selectedDestinationId = destination.id;
      _loadDestination(destination);
      _syncDraftToViewModel(destination);
    });
    await _reorderDestinationsAndTravelLegs();
  }

  Future<void> _removeDestination(String id) async {
    if (_destinations.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A trip needs at least one destination.')),
      );
      return;
    }
    final destination = _destinations.firstWhere((item) => item.id == id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove destination?'),
        content: Text(
          'Remove ${destination.destination} and its hotel and schedule from this trip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _persistSelectedDestination();
    final removedIndex = _destinations.indexWhere((item) => item.id == id);
    setState(() {
      _destinations.removeAt(removedIndex);
      _travelLegs.removeWhere(
        (leg) => leg.fromDestinationId == id || leg.toDestinationId == id,
      );
      _tripViewModel.removeSegment(id);
      if (_selectedDestinationId == id) {
        final nextIndex = removedIndex.clamp(0, _destinations.length - 1);
        _selectedDestinationId = _destinations[nextIndex].id;
        _tripViewModel.selectSegment(_selectedDestinationId);
        _loadDestination(_selectedDestination);
      }
    });
    await _reorderDestinationsAndTravelLegs();
  }

  Future<void> _editDestination(String id) async {
    _persistSelectedDestination();
    final destination = _destinations.firstWhere((item) => item.id == id);
    final value = await showDialog<AddDestinationValue>(
      context: context,
      builder: (_) => AddDestinationDialog(
        initialDestination: destination.destination,
        editing: true,
      ),
    );
    if (value == null || !mounted) return;
    final nextName = value.destination.trim();
    if (nextName == destination.destination) return;
    setState(() {
      destination.destination = nextName;
      destination.placeId = value.placeId;
      destination.plannerResult = null;
      destination.savedDays = const [];
      destination.selectedHotel = null;
      destination.hotelRecommendations = const [];
      destination.mapSearchArea = null;
      if (destination.id == _selectedDestinationId) {
        _loadDestination(destination);
      }
      _syncDraftToViewModel(destination);
    });
    await _reorderDestinationsAndTravelLegs();
  }

  Future<TravelEstimate?> _estimateIncomingTravel(
    String origin,
    String destination, {
    String? originPlaceId,
    String? destinationPlaceId,
  }) async {
    if (!AppConfig.hasGoogleMapsApiKey) return null;
    try {
      return await _travelTimeEstimator.estimate(
        mapService: MapService(apiKey: AppConfig.googleMapsApiKey),
        origin: origin,
        destination: destination,
        originPlaceId: originPlaceId,
        destinationPlaceId: destinationPlaceId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _reorderDestinationsAndTravelLegs() async {
    sortDestinationsByStartDate(_destinations);
    final oldLegs = {
      for (final leg in _travelLegs)
        '${leg.fromDestinationId}:${leg.toDestinationId}': leg,
    };
    final rebuilt = <TravelLegDraft>[];
    for (var index = 0; index < _destinations.length - 1; index++) {
      final origin = _destinations[index];
      final target = _destinations[index + 1];
      final old = oldLegs['${origin.id}:${target.id}'];
      final estimate = await _estimateIncomingTravel(
        origin.destination,
        target.destination,
        originPlaceId: origin.placeId,
        destinationPlaceId: target.placeId,
      );
      if (estimate == null) {
        if (old != null) rebuilt.add(old);
        continue;
      }
      rebuilt.add(
        TravelLegDraft(
          fromDestinationId: origin.id,
          toDestinationId: target.id,
          estimate: estimate,
          overrideMode: old?.overrideMode,
          overrideDurationHours: old?.overrideDurationHours,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _travelLegs
        ..clear()
        ..addAll(rebuilt);
    });
    _tripViewModel.clearDraftTrip();
    for (final destination in _destinations) {
      _syncDraftToViewModel(destination);
    }
    _tripViewModel.replaceTravelLegs(rebuilt);
    _tripViewModel.selectSegment(_selectedDestinationId);
  }

  Future<void> _editTravelLeg(TravelLegDraft leg) async {
    final controller = TextEditingController(
      text: leg.durationHours.toStringAsFixed(1),
    );
    var mode = leg.mode;
    final result = await showDialog<({TravelMode mode, double hours})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Edit travel estimate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TravelMode>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Travel mode'),
                items: TravelMode.values
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item.name)),
                    )
                    .toList(),
                onChanged: (value) => update(() => mode = value ?? mode),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Duration (hours)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final hours = double.tryParse(controller.text);
                if (hours != null && hours > 0) {
                  Navigator.pop(context, (mode: mode, hours: hours));
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    var datesCleared = false;
    setState(() {
      leg.overrideMode = result.mode;
      leg.overrideDurationHours = result.hours;
      final origin = _destinations
          .where((item) => item.id == leg.fromDestinationId)
          .firstOrNull;
      final target = _destinations
          .where((item) => item.id == leg.toDestinationId)
          .firstOrNull;
      final transit = origin?.dates == null
          ? null
          : transitDateRange(origin!.dates!.end, leg.transitDays);
      if (target?.dates != null &&
          transit != null &&
          dateRangeOverlaps(target!.dates!, [transit])) {
        target.dates = null;
        target.plannerResult = null;
        datesCleared = true;
        if (target.id == _selectedDestinationId) {
          _loadDestination(target);
        }
      }
    });
    _tripViewModel.replaceTravelLegs(_travelLegs);
    if (datesCleared && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The next destination dates overlapped the updated travel time. Please choose new dates.',
          ),
        ),
      );
    }
  }

  List<DateTimeRange> _unavailableDateRanges({String? excludingId}) {
    final ranges = _destinations
        .where((item) => item.id != excludingId && item.dates != null)
        .map((item) => item.dates!)
        .toList();
    for (final leg in _travelLegs) {
      final origin = _destinations
          .where((item) => item.id == leg.fromDestinationId)
          .firstOrNull;
      if (origin?.dates == null) continue;
      final transit = transitDateRange(origin!.dates!.end, leg.transitDays);
      if (transit != null) ranges.add(transit);
    }
    return ranges;
  }

  @override
  void dispose() {
    _preferenceViewModel?.removeListener(_onPreferenceChanged);
    budgetController.removeListener(_onSetupFieldChanged);
    destinationController.removeListener(_onSetupFieldChanged);
    destinationController.dispose();
    tripTitleController.dispose();
    budgetController.dispose();
    _currencyRates.dispose();
    super.dispose();
  }

  void _onSetupFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final unavailableRanges = _unavailableDateRanges(
      excludingId: _selectedDestinationId,
    );
    final selected = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDateRange: dates,
      helpText: 'Select available destination dates',
      selectableDayPredicate: (day, selectedStart, selectedEnd) =>
          !isDateUnavailable(day, unavailableRanges),
    );
    if (selected != null && mounted) {
      if (dateRangeOverlaps(selected, unavailableRanges)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('These dates overlap another destination.'),
          ),
        );
        return;
      }
      setState(() {
        dates = selected;
        // Dates can be chosen before any destination exists. _addDestination
        // carries them onto the first destination added.
        final destination = _selectedDestinationOrNull;
        if (destination != null) {
          destination.dates = selected;
          _syncDraftToViewModel(destination);
        }
      });
      await _reorderDestinationsAndTravelLegs();
    }
  }

  Future<void> _chooseMapArea() async {
    final service = _mapService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A Google Maps API key is required to search an area.'),
        ),
      );
      return;
    }

    final destination = destinationController.text.trim();
    if (destination.isEmpty) return;
    try {
      final current = _selectedDestination.mapSearchArea;
      final center = current == null
          ? await service.resolveDestinationCenter(
              destination,
              placeId: _selectedDestination.placeId,
            )
          : Coordinates(
              latitude: current.latitude,
              longitude: current.longitude,
            );
      if (!mounted) return;
      final selected = await showDialog<MapSearchArea>(
        context: context,
        builder: (_) => MapAreaPickerDialog(
          destination: destination,
          initialCenter: LatLng(center.latitude, center.longitude),
          initialArea: current,
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _selectedDestination.mapSearchArea = selected;
        _selectedDestination.plannerResult = null;
        _selectedDestination.savedDays = const [];
        plannerResult = null;
        planGenerated = false;
        placeDataSource =
            'Custom map area • ${selected.radiusLabel} search radius';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this destination on the map. $error')),
      );
    }
  }

  void _clearMapArea() {
    setState(() {
      _selectedDestination.mapSearchArea = null;
      _selectedDestination.plannerResult = null;
      _selectedDestination.savedDays = const [];
      plannerResult = null;
      planGenerated = false;
      placeDataSource = 'Google Places ready';
    });
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
    final previous = savedPreference;
    setState(() {
      isLoadingPreference = false;
      savedPreference = preference;
      preferenceError = preference == null
          ? viewModel.errorMessage ?? 'No saved preference was found.'
          : null;
      // On the first load, follow the saved activity level. After that, only
      // when it is what changed - a reload must not throw away the pace the
      // user picked on this page.
      if (preference != null &&
          (previous == null ||
              previous.activityLevel != preference.activityLevel)) {
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
    if (dates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose travel dates before generating a plan.'),
        ),
      );
      return;
    }
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
      var candidatePlaces = _destinationPlaceService == null
          ? List<TravelPlace>.of(mockTokyoPlaces)
          : <TravelPlace>[];
      var centerLatitude = 35.6762;
      var centerLongitude = 139.6503;
      var nextPlaceDataSource =
          'Mock Tokyo data • Google API key not configured';
      var nextHotels = <HotelStay>[];
      String? nextCalibrationNote;

      final destinationPlaceService = _destinationPlaceService;
      if (destinationPlaceService != null) {
        try {
          final selectedArea = _selectedDestination.mapSearchArea;
          final priceContext = PriceContext(
            currencyCode: currencyCode,
            totalBudget: budget,
            spendingStyle: preference.spendingStyle,
            days: dates == null
                ? 3
                : dates!.end.difference(dates!.start).inDays + 1,
            travelers: travelers,
          );
          final destinationCandidates = selectedArea == null
              ? await destinationPlaceService.loadForDestination(
                  destination,
                  placeId: _selectedDestination.placeId,
                  priceContext: priceContext,
                )
              : await destinationPlaceService.loadForArea(
                  center: Coordinates(
                    latitude: selectedArea.latitude,
                    longitude: selectedArea.longitude,
                  ),
                  radiusMeters: selectedArea.radiusMeters,
                  priceContext: priceContext,
                );
          if (destinationCandidates.places.isNotEmpty) {
            candidatePlaces = destinationCandidates.places;
            centerLatitude = destinationCandidates.center.latitude;
            centerLongitude = destinationCandidates.center.longitude;
            nextPlaceDataSource = selectedArea == null
                ? 'Live Google Places • ${candidatePlaces.length} candidates'
                : 'Custom ${selectedArea.radiusLabel} map area • '
                      '${candidatePlaces.length} candidates';
            nextHotels = destinationCandidates.hotels;
            nextCalibrationNote = destinationCandidates.calibration.explanation;
          } else {
            nextPlaceDataSource =
                'Google Places returned no candidates in this area';
          }
        } catch (error) {
          candidatePlaces = const [];
          nextPlaceDataSource = 'Google Places unavailable';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not load Google Places for this area. $error',
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
        travelers: travelers,
        currencyCode: currencyCode,
      );

      final generatedResult = _planner
          .generatePlan(
            trip: trip,
            preference: preference,
            candidatePlaces: candidatePlaces,
            centerLatitude: centerLatitude,
            centerLongitude: centerLongitude,
          )
          .copyWith(
            calibrationNote: nextCalibrationNote,
            priceDisplayMode: priceDisplayMode,
          );

      final nightCount = dates == null
          ? (dayCount - 1).clamp(1, dayCount)
          : dates!.end.difference(dates!.start).inDays.clamp(1, dayCount);
      final roomCount = ((travelers + 1) ~/ 2).clamp(1, travelers);
      var nextHotel = selectedHotel?.copyWith(
        nights: nightCount,
        rooms: roomCount,
      );
      nextHotel ??= _pickHotelWithinBudget(
        nextHotels,
        nights: nightCount,
        rooms: roomCount,
        accommodationBudget: generatedResult.budgetAllocation.accommodation,
      );
      final result = _resultWithHotel(generatedResult, nextHotel);

      if (!mounted) return;

      setState(() {
        plannerResult = result;
        _generatedFromPreference = savedPreference;
        _selectedDestination.currencyCode = currencyCode;
        planGenerated = true;
        placeDataSource = nextPlaceDataSource;
        hotelRecommendations = nextHotels
            .map(
              (hotel) => hotel.copyWith(nights: nightCount, rooms: roomCount),
            )
            .toList();
        selectedHotel = nextHotel;
        _persistSelectedDestination();
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

  PlannerResult _resultWithHotel(PlannerResult result, HotelStay? hotel) {
    final issues = result.validation.issues
        .where(
          (issue) =>
              issue.code != PlannerValidationCode.accommodationCostExceeded &&
              issue.code != PlannerValidationCode.totalTripCostExceeded,
        )
        .toList();
    if (hotel != null &&
        hotel.totalCost > result.budgetAllocation.accommodation + 0.001) {
      issues.add(
        PlannerValidationIssue(
          code: PlannerValidationCode.accommodationCostExceeded,
          severity: PlannerValidationSeverity.warning,
          message:
              'Your hotel estimate of '
              '${Money.format(hotel.totalCost, result.currencyCode)} exceeds '
              'the '
              '${Money.format(result.budgetAllocation.accommodation, result.currencyCode)} '
              'accommodation allocation.',
        ),
      );
    }
    if (hotel != null &&
        result.partyEstimatedCost + hotel.totalCost >
            result.budgetAllocation.total + 0.001) {
      issues.add(
        const PlannerValidationIssue(
          code: PlannerValidationCode.totalTripCostExceeded,
          severity: PlannerValidationSeverity.warning,
          message:
              'The hotel, meals, and activities exceed the total trip budget.',
        ),
      );
    }
    return PlannerResult(
      budgetAllocation: result.budgetAllocation,
      validation: PlannerValidationResult(issues: issues),
      profile: result.profile,
      rankedPlaces: result.rankedPlaces,
      days: result.days,
      hotel: hotel,
      startTimeOverrides: result.startTimeOverrides,
      travelers: result.travelers,
      currencyCode: result.currencyCode,
      calibrationNote: result.calibrationNote,
      priceDisplayMode: result.priceDisplayMode,
    );
  }

  /// The best-rated hotel the accommodation allocation can actually cover.
  ///
  /// The recommendation list is sorted by rating, so taking the first one
  /// picked the most highly reviewed hotel regardless of price and reliably
  /// blew the allocation. When nothing fits, the cheapest is chosen so the
  /// warning the user sees is about a genuine shortfall rather than an
  /// arbitrary pick.
  HotelStay? _pickHotelWithinBudget(
    List<HotelStay> hotels, {
    required int nights,
    required int rooms,
    required double accommodationBudget,
  }) {
    if (hotels.isEmpty) return null;

    final sized = hotels
        .map((hotel) => hotel.copyWith(nights: nights, rooms: rooms))
        .toList();

    final affordable = sized
        .where((hotel) => hotel.totalCost <= accommodationBudget + 0.001)
        .toList();
    if (affordable.isNotEmpty) {
      affordable.sort((left, right) => right.rating.compareTo(left.rating));
      return affordable.first;
    }

    sized.sort((left, right) => left.totalCost.compareTo(right.totalCost));
    return sized.first;
  }

  void _selectRecommendedHotel(HotelStay hotel) {
    final updated = hotel.copyWith(
      nightlyRate: selectedHotel?.id == hotel.id
          ? selectedHotel?.nightlyRate ?? 0
          : hotel.nightlyRate,
      nights: selectedHotel?.nights ?? hotel.nights,
      rooms: selectedHotel?.rooms ?? hotel.rooms,
    );
    setState(() {
      selectedHotel = updated;
      if (plannerResult != null) {
        plannerResult = _resultWithHotel(plannerResult!, updated);
      }
      _persistSelectedDestination();
    });
  }

  Future<void> _editHotel() async {
    final initial = selectedHotel;
    final edited = await showDialog<HotelStay>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HotelEditorDialog(
        initial: initial,
        defaultNights:
            dates?.end.difference(dates!.start).inDays.clamp(1, 365) ?? 1,
        defaultRooms: ((travelers + 1) ~/ 2).clamp(1, travelers),
        mapService: AppConfig.hasGoogleMapsApiKey
            ? MapService(apiKey: AppConfig.googleMapsApiKey)
            : null,
        currencyCode: currencyCode,
      ),
    );
    if (!mounted || edited == null) return;
    setState(() {
      selectedHotel = edited;
      if (plannerResult != null) {
        plannerResult = _resultWithHotel(plannerResult!, edited);
      }
      _persistSelectedDestination();
    });
  }

  Future<void> _openManualPlanner() async {
    if (plannerResult == null || plannerResult!.rankedPlaces.isEmpty) {
      await _generatePlan();
    }
    final current = plannerResult;
    if (!mounted || current == null || current.rankedPlaces.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No destination places are available to add yet.'),
          ),
        );
      }
      return;
    }

    final editedDays = await showDialog<List<PlannerDay>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ManualPlannerDialog(result: current),
    );
    if (!mounted || editedDays == null) return;

    final validation = const PlannerValidationService().validate(
      days: editedDays,
      rankedPlaces: current.rankedPlaces,
      profile: current.profile,
      budgetAllocation: current.budgetAllocation,
      travelers: current.partySize,
      currencyCode: current.currencyCode,
      allowUserOverrides: true,
    );
    setState(() {
      plannerResult = PlannerResult(
        budgetAllocation: current.budgetAllocation,
        validation: validation,
        profile: current.profile,
        rankedPlaces: current.rankedPlaces,
        days: editedDays,
        hotel: current.hotel,
        startTimeOverrides: current.startTimeOverrides,
        travelers: current.travelers,
        currencyCode: current.currencyCode,
        calibrationNote: current.calibrationNote,
        priceDisplayMode: current.priceDisplayMode,
      );
      planGenerated = true;
      _persistSelectedDestination();
    });
  }

  /// Changing the currency invalidates every amount in the plan.
  ///
  /// Place costs, hotel rates and the whole price calibration are derived in
  /// one currency, and nothing here is ever converted, so a currency change
  /// has to rebuild the plan rather than relabel it. Estimated hotel rates are
  /// dropped for the same reason; a rate the user typed themselves is kept,
  /// because only they know whether the figure still means what they intended.
  Future<void> _setCurrency(String code) async {
    final next = Money.normalize(code);
    if (next == currencyCode) return;
    final previous = currencyCode;

    // Persist whatever is in the budget field before touching anything, so the
    // number being converted is the one the user can actually see.
    _persistSelectedDestination();

    final exchangeRate = await _currencyRates.rate(from: previous, to: next);
    if (!mounted) return;

    // Plans cached on the other destinations were priced in the old currency.
    // Their per-stop amounts still carry their own currency, but their totals
    // would be relabelled, so they are dropped and re-planned on demand.
    final staleDestinations = _destinations
        .where(
          (destination) =>
              destination.id != _selectedDestinationId &&
              (destination.plannerResult != null ||
                  destination.savedDays.isNotEmpty),
        )
        .length;

    setState(() {
      currencyCode = next;

      for (final destination in _destinations) {
        destination.currencyCode = next;

        if (exchangeRate != null) {
          destination.budget = Money.roundBudget(
            exchangeRate.convert(destination.budget),
          );
        }

        // An estimated rate was derived from the old currency's calibration
        // and cannot be carried across. A rate the user typed is their own
        // money and converts like the budget does.
        final hotel = destination.selectedHotel;
        if (hotel != null) {
          if (hotel.nightlyRateEstimated) {
            destination.selectedHotel = null;
          } else if (exchangeRate != null) {
            destination.selectedHotel = hotel.copyWith(
              nightlyRate: exchangeRate.convert(hotel.nightlyRate),
            );
          }
        }
        destination.hotelRecommendations = const [];

        if (destination.id != _selectedDestinationId) {
          destination.plannerResult = null;
          destination.savedDays = const [];
        }
      }

      final selected = _selectedDestinationOrNull;
      if (selected != null) {
        // Match _loadDestination's formatting so an unconverted budget keeps
        // any cents the user typed.
        budgetController.text = selected.budget.toStringAsFixed(
          selected.budget == selected.budget.roundToDouble() ? 0 : 2,
        );
        selectedHotel = selected.selectedHotel;
      }
      hotelRecommendations = const [];
    });

    if (mounted) {
      final staleNote = staleDestinations == 0
          ? ''
          : ' $staleDestinations other '
                '${staleDestinations == 1 ? 'destination needs' : 'destinations need'} '
                'regenerating.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exchangeRate == null
                ? 'Could not reach an exchange rate service, so your budget '
                      'was left as typed and is now read as $next. Edit it if '
                      'that is not what you meant.$staleNote'
                : 'Converted your budget from $previous to $next at '
                      '${exchangeRate.description}, rounded to a whole '
                      'amount.$staleNote',
          ),
        ),
      );
    }

    if (planGenerated) await _generatePlan();
  }

  /// Switching between per-person and total changes presentation only, so the
  /// plan is re-priced in place rather than regenerated.
  void _setPriceDisplayMode(PriceDisplayMode mode) {
    setState(() {
      priceDisplayMode = mode;
      final current = plannerResult;
      if (current != null) {
        plannerResult = current.copyWith(priceDisplayMode: mode);
      }
    });
  }

  void _selectPlan(String value) {
    setState(() => selectedPlan = value);

    if (planGenerated) {
      _generatePlan();
    }
  }

  Future<TripAiProposal> _proposeAiChange(
    String instruction,
    List<Map<String, String>> history,
  ) async {
    if (_destinations.isEmpty || plannerResult == null) {
      return const TripAiProposal(
        command: TripAiCommand(
          type: TripAiCommandType.unsupported,
          explanation:
              'Generate a destination schedule before asking AI to change it.',
        ),
        summary:
            'Generate a destination schedule before asking AI to change it.',
      );
    }
    final pending = _pendingAiChoice;
    final numericReply = int.tryParse(instruction.trim());
    if (pending != null && numericReply != null) {
      final resolved = _resolvePendingAiChoice(pending, numericReply);
      if (resolved != null) return resolved;
    }
    _pendingAiChoice = null;
    final selected = _selectedDestination;
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final proposal = await _tripAiService.propose(
      instruction: instruction,
      idToken: token,
      history: history,
      context: {
        'destinationId': selected.id,
        'destination': selected.destination,
        'budget': selected.budget,
        'startDate': selected.dates?.start.toIso8601String(),
        'endDate': selected.dates?.end.toIso8601String(),
        'plannerStyle': selectedPlan,
        'currency': currencyCode,
        'travelers': travelers,
        'costBreakdown': CostBreakdown.from(plannerResult!).toPlainText(),
        'hotel': selectedHotel?.name,
        'days': plannerResult!.days
            .map(
              (day) => {
                'dayNumber': day.dayNumber,
                'places': day.places.map((item) => item.place.name).toList(),
                'stops': const DailyTimeScheduleService()
                    .schedule(
                      day.places,
                      startTimeOverrides: plannerResult!.startTimeOverrides,
                    )
                    .asMap()
                    .entries
                    .map(
                      (entry) => {
                        'number': entry.key + 1,
                        'name': entry.value.scoredPlace.place.name,
                        'role': entry.value.roleLabel,
                        'startMinutes': entry.value.startMinutes,
                        'category': entry.value.scoredPlace.place.category,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      },
    );
    if (proposal.command.type == TripAiCommandType.explainCost) {
      // Answer from the plan rather than from whatever the model wrote, so
      // the chat and the breakdown sheet can never quote different numbers.
      final explanation = CostBreakdown.from(plannerResult!).toPlainText();
      return TripAiProposal(
        command: proposal.command.copyWith(message: explanation),
        summary: explanation,
      );
    }
    if (proposal.command.type == TripAiCommandType.setDayStartTime &&
        proposal.command.dayNumber == null) {
      _pendingAiChoice = _PendingAiChoice(
        command: proposal.command,
        awaitingScheduleDay: true,
      );
      return _questionProposal(
        'Which day should start at the requested time? Reply with the day number.',
      );
    }
    return _resolveStopProposal(proposal);
  }

  TripAiProposal _resolveStopProposal(TripAiProposal proposal) {
    final command = proposal.command;
    if (!const {
      TripAiCommandType.removeStop,
      TripAiCommandType.moveStop,
      TripAiCommandType.replaceStop,
    }.contains(command.type)) {
      return proposal;
    }
    if (command.type == TripAiCommandType.removeStop &&
        command.activityNumbers.isNotEmpty &&
        command.dayNumber != null) {
      return proposal;
    }
    if (command.type == TripAiCommandType.replaceStop &&
        command.activityNumbers.length == 1 &&
        command.dayNumber != null) {
      final day = plannerResult!.days
          .where((item) => item.dayNumber == command.dayNumber)
          .firstOrNull;
      final number = command.activityNumbers.single;
      if (day == null || number < 1 || number > day.places.length) {
        return _questionProposal(
          'Activity $number does not exist on day ${command.dayNumber}. Use a number shown on that day.',
        );
      }
      final name = day.places[number - 1].place.name;
      return TripAiProposal(
        command: command.copyWith(activityName: name),
        summary: _resolvedCommandSummary(command, name),
      );
    }
    final requestedRole = (command.mealType ?? command.activityName ?? '')
        .toLowerCase()
        .trim();
    if (const {'breakfast', 'lunch', 'dinner'}.contains(requestedRole)) {
      if (command.dayNumber == null) {
        _pendingAiChoice = _PendingAiChoice(
          command: command,
          awaitingDay: true,
        );
        return _questionProposal(
          'Which day should I ${command.type == TripAiCommandType.replaceStop ? 'replace' : 'remove'} $requestedRole on? Reply with the day number.',
        );
      }
      return _resolveMealRole(command, command.dayNumber!, requestedRole);
    }
    final requestedName = command.activityName?.trim();
    if (requestedName == null || requestedName.isEmpty) return proposal;
    final candidates = _stopNameMatcher.rank(
      requestedName,
      plannerResult!.days
          .expand((day) => day.places)
          .map((item) => item.place.name),
    );
    if (candidates.isEmpty) return proposal;
    final best = candidates.first;
    final margin = candidates.length == 1
        ? 1.0
        : best.score - candidates[1].score;
    if (best.score >= 0.88 || (best.score >= 0.72 && margin >= 0.1)) {
      return TripAiProposal(
        command: command.copyWith(activityName: best.name),
        summary: _resolvedCommandSummary(command, best.name),
      );
    }
    final minimumChoiceScore = (best.score - 0.25).clamp(0.35, 1.0);
    final choices = candidates
        .where((item) => item.score >= minimumChoiceScore)
        .take(5)
        .map((item) => item.name)
        .toList();
    _pendingAiChoice = _PendingAiChoice(command: command, choices: choices);
    return _questionProposal(
      'I could not confidently match “$requestedName”. Which stop did you mean?\n${_numberedChoices(choices)}\nReply with its number.',
    );
  }

  TripAiProposal? _resolvePendingAiChoice(_PendingAiChoice pending, int reply) {
    if (pending.awaitingDay) {
      final role =
          (pending.command.mealType ?? pending.command.activityName ?? '')
              .toLowerCase();
      if (!plannerResult!.days.any((day) => day.dayNumber == reply)) {
        return _questionProposal(
          'Day $reply does not exist. Reply with a day number from this itinerary.',
        );
      }
      _pendingAiChoice = null;
      return _resolveMealRole(pending.command, reply, role);
    }
    if (pending.awaitingScheduleDay) {
      if (!plannerResult!.days.any((day) => day.dayNumber == reply)) {
        return _questionProposal(
          'Day $reply does not exist. Reply with a day number from this itinerary.',
        );
      }
      _pendingAiChoice = null;
      final command = pending.command.copyWith(dayNumber: reply);
      return TripAiProposal(
        command: command,
        summary:
            'Start day $reply at the requested time and reschedule all later stops.',
      );
    }
    if (reply < 1 || reply > pending.choices.length) {
      return _questionProposal(
        'Choose one of these stops:\n${_numberedChoices(pending.choices)}',
      );
    }
    _pendingAiChoice = null;
    final name = pending.choices[reply - 1];
    return TripAiProposal(
      command: pending.command.copyWith(activityName: name),
      summary: _resolvedCommandSummary(pending.command, name),
    );
  }

  TripAiProposal _resolveMealRole(
    TripAiCommand command,
    int dayNumber,
    String role,
  ) {
    final day = plannerResult!.days.firstWhere(
      (item) => item.dayNumber == dayNumber,
    );
    final scheduled = const DailyTimeScheduleService().schedule(
      day.places,
      startTimeOverrides: plannerResult!.startTimeOverrides,
    );
    final match = scheduled
        .where((stop) => stop.roleLabel.toLowerCase() == role)
        .firstOrNull;
    if (match == null) {
      _pendingAiChoice = null;
      return _questionProposal('Day $dayNumber does not contain $role.');
    }
    final name = match.scoredPlace.place.name;
    _pendingAiChoice = null;
    return TripAiProposal(
      command: command.copyWith(activityName: name, dayNumber: dayNumber),
      summary: _resolvedCommandSummary(command, name),
    );
  }

  TripAiProposal _questionProposal(String message) => TripAiProposal(
    command: TripAiCommand(
      type: TripAiCommandType.unsupported,
      destinationId: _selectedDestinationId,
      explanation: message,
    ),
    summary: message,
  );

  String _resolvedCommandSummary(
    TripAiCommand command,
    String name,
  ) => switch (command.type) {
    TripAiCommandType.removeStop => 'Remove $name from the itinerary.',
    TripAiCommandType.moveStop =>
      'Move $name to day ${command.targetDayNumber}.',
    TripAiCommandType.replaceStop =>
      'Replace $name with the best available ${command.replacementPreference ?? 'alternative'}.',
    _ => command.explanation,
  };

  String _numberedChoices(List<String> choices) => List.generate(
    choices.length,
    (index) => '${index + 1}. ${choices[index]}',
  ).join('\n');

  Future<String> _applyAiCommand(TripAiCommand command) async {
    final current = plannerResult;
    if (current == null) {
      return 'Generate a plan first, then ask me to refine it.';
    }
    if (command.destinationId != null &&
        command.destinationId != _selectedDestinationId) {
      return 'That proposal belongs to another destination. Nothing was changed.';
    }
    final snapshot = _captureAiUndoSnapshot();
    if (command.type == TripAiCommandType.changeBudget) {
      final currentBudget = double.tryParse(budgetController.text.trim());
      final requestedBudget =
          command.budget ??
          (currentBudget == null ? null : currentBudget * 0.85);
      if (requestedBudget == null || requestedBudget <= 0) {
        return 'I could not determine a valid total budget from that request.';
      }
      budgetController.text = requestedBudget.toStringAsFixed(0);
      await _generatePlan();
      final regenerated = plannerResult;
      if (regenerated == null || !regenerated.validation.isValid) {
        _restoreAiSnapshot(snapshot);
        return 'I could not create a valid plan at that budget.';
      }
      if (regenerated.partyEstimatedTripCost > requestedBudget + 0.01) {
        final attemptedTotal = regenerated.partyEstimatedTripCost;
        _restoreAiSnapshot(snapshot);
        return 'I could not create a complete plan under '
            '${Money.format(requestedBudget, currencyCode)}. The lowest '
            'generated total was '
            '${Money.format(attemptedTotal, currencyCode)}, so nothing was '
            'changed.';
      }
      _rememberAiUndo(snapshot);
      return 'Regenerated the itinerary with a total budget of '
          '${Money.format(requestedBudget, currencyCode)}. Validation passed.';
    }
    if (command.type == TripAiCommandType.changeStyle) {
      final style = command.style;
      if (!const ['Relaxed', 'Balanced', 'Explorer'].contains(style)) {
        return 'That planning style is not supported.';
      }
      if (selectedPlan == style) {
        return '$style is already selected. Nothing was changed.';
      }
      setState(() => selectedPlan = style!);
      await _generatePlan();
      if (plannerResult == null || identical(plannerResult, snapshot.result)) {
        _restoreAiSnapshot(snapshot);
        return 'I could not regenerate this destination using that style.';
      }
      _rememberAiUndo(snapshot);
      return 'Regenerated this destination using the $style style.';
    }
    final instruction = switch (command.type) {
      TripAiCommandType.relaxDay =>
        command.dayNumber == null
            ? 'relax schedule'
            : 'make day ${command.dayNumber} more relaxing',
      TripAiCommandType.addFood => 'add more food',
      TripAiCommandType.removeMuseums => 'remove museums',
      TripAiCommandType.reduceWalking => 'less walking',
      TripAiCommandType.removeStop ||
      TripAiCommandType.moveStop ||
      TripAiCommandType.replaceStop ||
      TripAiCommandType.swapStops ||
      TripAiCommandType.replaceWithScheduledStop ||
      TripAiCommandType.moveStopRelative ||
      TripAiCommandType.moveStopTime => '',
      TripAiCommandType.addStops ||
      TripAiCommandType.removeStops ||
      TripAiCommandType.setDayStartTime => '',
      TripAiCommandType.explain || TripAiCommandType.unsupported => '',
      _ => '',
    };
    final refinement = switch (command.type) {
      TripAiCommandType.removeStop when command.activityName != null =>
        _refinementService.removeStop(current, command.activityName!),
      TripAiCommandType.removeStop
          when command.dayNumber != null &&
              command.activityNumbers.isNotEmpty =>
        _refinementService.removeNumberedStops(
          current,
          command.dayNumber!,
          command.activityNumbers,
        ),
      TripAiCommandType.moveStop
          when command.activityName != null &&
              command.targetDayNumber != null =>
        _refinementService.moveStop(
          current,
          command.activityName!,
          command.targetDayNumber!,
        ),
      TripAiCommandType.replaceStop when command.activityName != null =>
        await _replaceStop(current, command),
      TripAiCommandType.addFood => _refinementService.addFood(
        current,
        dayNumber: command.dayNumber,
        mealType: command.mealType,
      ),
      TripAiCommandType.swapStops ||
      TripAiCommandType.replaceWithScheduledStop ||
      TripAiCommandType.moveStopRelative ||
      TripAiCommandType.moveStopTime => _structuredScheduleRefinement(
        current,
        command,
      ),
      TripAiCommandType.addStops => _refinementService.addStops(
        current,
        dayNumber: command.dayNumber,
        requestedCount: command.stopCount,
        category: command.stopCategory,
      ),
      TripAiCommandType.removeStops when command.stopCount != null =>
        _refinementService.removeStops(
          current,
          dayNumber: command.dayNumber,
          count: command.stopCount!,
          category: command.stopCategory,
        ),
      TripAiCommandType.setDayStartTime
          when command.dayNumber != null && command.startMinutes != null =>
        _refinementService.setDayStartTime(
          current,
          command.dayNumber!,
          command.startMinutes!,
        ),
      _ when instruction.isNotEmpty => _refinementService.refine(
        currentPlan: current,
        instruction: instruction,
      ),
      _ => null,
    };
    if (refinement == null) return command.explanation;
    if (refinement.changed && refinement.plan.validation.isValid && mounted) {
      setState(() => plannerResult = refinement.plan);
      _rememberAiUndo(snapshot);
    }
    return refinement.message;
  }

  Future<PlanRefinementResult> _replaceStop(
    PlannerResult current,
    TripAiCommand command,
  ) async {
    if (command.replacementCriterion != 'closer' || _mapService == null) {
      return _refinementService.replaceStop(
        current,
        command.activityName!,
        replacementPreference: command.replacementPreference,
        replacementCriterion: command.replacementCriterion,
      );
    }
    return _refinementService.replaceStopRouteAware(
      current,
      command.activityName!,
      replacementPreference: command.replacementPreference,
      routeDurationHours:
          (originLat, originLng, destinationLat, destinationLng) async {
            final estimate = await _mapService.getDrivingRouteEstimate(
              origin: Coordinates(latitude: originLat, longitude: originLng),
              destination: Coordinates(
                latitude: destinationLat,
                longitude: destinationLng,
              ),
            );
            return estimate.durationHours;
          },
    );
  }

  PlanRefinementResult _structuredScheduleRefinement(
    PlannerResult current,
    TripAiCommand command,
  ) {
    final sourceName = _resolveStopReference(current, command.sourceStop);
    if (sourceName == null) {
      return PlanRefinementResult(
        plan: current,
        changed: false,
        message:
            'I could not uniquely resolve the source stop. Use its day and displayed name or number.',
      );
    }
    if (command.type == TripAiCommandType.moveStopTime) {
      final day = command.targetDayNumber;
      final time = command.startMinutes;
      if (day == null || time == null) {
        return PlanRefinementResult(
          plan: current,
          changed: false,
          message: 'Tell me both the destination day and time.',
        );
      }
      return _refinementService.moveStopToTime(current, sourceName, day, time);
    }
    final targetName = _resolveStopReference(current, command.targetStop);
    if (targetName == null) {
      return PlanRefinementResult(
        plan: current,
        changed: false,
        message:
            'I could not uniquely resolve the target stop. Use its day and displayed name or number.',
      );
    }
    return switch (command.type) {
      TripAiCommandType.swapStops => _refinementService.swapStops(
        current,
        sourceName,
        targetName,
      ),
      TripAiCommandType.replaceWithScheduledStop =>
        _refinementService.replaceWithScheduledStop(
          current,
          sourceName,
          targetName,
        ),
      TripAiCommandType.moveStopRelative => _refinementService.moveStopRelative(
        current,
        sourceName,
        targetName,
        command.relativePosition ?? 'before',
      ),
      _ => PlanRefinementResult(
        plan: current,
        changed: false,
        message: 'That schedule edit is not supported.',
      ),
    };
  }

  String? _resolveStopReference(
    PlannerResult current,
    TripAiStopReference? reference,
  ) {
    if (reference == null) return null;
    final days = reference.dayNumber == null
        ? current.days
        : current.days
              .where((day) => day.dayNumber == reference.dayNumber)
              .toList();
    if (days.isEmpty) return null;
    final number = reference.activityNumber;
    if (number != null) {
      if (days.length != 1 ||
          number < 1 ||
          number > days.single.places.length) {
        return null;
      }
      return days.single.places[number - 1].place.name;
    }
    final meal = reference.mealType;
    if (meal != null) {
      if (days.length != 1) return null;
      return const DailyTimeScheduleService()
          .schedule(
            days.single.places,
            startTimeOverrides: current.startTimeOverrides,
          )
          .where((stop) => stop.roleLabel.toLowerCase() == meal)
          .firstOrNull
          ?.scoredPlace
          .place
          .name;
    }
    final name = reference.activityName;
    if (name == null) return null;
    final matches = _stopNameMatcher.rank(
      name,
      days.expand((day) => day.places).map((item) => item.place.name),
    );
    if (matches.isEmpty || matches.first.score < 0.72) return null;
    if (matches.length > 1 &&
        matches.first.score < 0.88 &&
        matches.first.score - matches[1].score < 0.1) {
      return null;
    }
    return matches.first.name;
  }

  _AiUndoSnapshot _captureAiUndoSnapshot() {
    final selected = _selectedDestination;
    return _AiUndoSnapshot(
      destinationId: selected.id,
      result: plannerResult,
      budgetText: budgetController.text,
      selectedPlan: selectedPlan,
      hotelRecommendations: List<HotelStay>.of(hotelRecommendations),
      selectedHotel: selectedHotel,
      placeDataSource: placeDataSource,
      planGenerated: planGenerated,
    );
  }

  void _rememberAiUndo(_AiUndoSnapshot snapshot) {
    _aiUndoSnapshot = snapshot;
    final previous = snapshot.result;
    if (previous != null) {
      final selected = _selectedDestination;
      selected.undoDays = List<PlannerDay>.of(previous.days);
      selected.undoBudget = double.tryParse(snapshot.budgetText);
      selected.undoStyle = snapshot.selectedPlan;
    }
    _persistSelectedDestination();
  }

  void _restoreAiSnapshot(_AiUndoSnapshot snapshot) {
    if (!mounted || snapshot.destinationId != _selectedDestinationId) return;
    setState(() {
      plannerResult = snapshot.result;
      budgetController.text = snapshot.budgetText;
      selectedPlan = snapshot.selectedPlan;
      hotelRecommendations = List<HotelStay>.of(snapshot.hotelRecommendations);
      selectedHotel = snapshot.selectedHotel;
      placeDataSource = snapshot.placeDataSource;
      planGenerated = snapshot.planGenerated;
      _persistSelectedDestination();
    });
  }

  Future<String> _undoAiChange() async {
    final snapshot = _aiUndoSnapshot;
    if (snapshot == null) return 'There is no AI change to undo.';
    if (snapshot.destinationId != _selectedDestinationId) {
      return 'Select the destination changed by AI before undoing it.';
    }
    _restoreAiSnapshot(snapshot);
    _aiUndoSnapshot = null;
    final selected = _selectedDestination;
    selected.undoDays = const [];
    selected.undoBudget = null;
    selected.undoStyle = null;
    _persistSelectedDestination();
    return 'Restored the plan from before the last AI change.';
  }

  bool _canUndoAiChange() =>
      _aiUndoSnapshot?.destinationId == _selectedDestinationId;

  Future<void> _saveTripDraft() async {
    _persistSelectedDestination();
    final viewModel = _tripViewModel;
    final segments = viewModel.draftSegments;
    final ownerId = context.read<AuthViewModel>().user?.uid;
    if (segments.isEmpty || ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add destination dates and sign in before saving.'),
        ),
      );
      return;
    }
    if (viewModel.currentTrip != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update saved trip?'),
          content: Text(
            'Save these changes to ${viewModel.currentTrip!.title ?? viewModel.currentTrip!.destination}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update trip'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (viewModel.currentTrip == null) {
      final first = segments.first;
      final last = segments.last;
      await viewModel.createTrip(
        Trip(
          id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
          ownerId: ownerId,
          title: tripTitleController.text.trim().isEmpty
              ? null
              : tripTitleController.text.trim(),
          destination: segments.map((item) => item.destination).join(' → '),
          budget: segments.fold(
            0,
            (total, item) => total + item.allocatedBudget,
          ),
          days: segments.fold(0, (total, item) => total + item.numberOfDays),
          status: 'draft',
          startDate: first.startDate,
          endDate: last.endDate,
          segments: segments,
        ),
      );
    } else {
      await viewModel.saveDraftSegmentsToCurrentTrip(
        title: tripTitleController.text.trim().isEmpty
            ? null
            : tripTitleController.text.trim(),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          viewModel.errorMessage ?? 'Trip draft saved to Firestore.',
        ),
      ),
    );
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
            onPressed: _destinations.isEmpty ? null : _saveTripDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save plan'),
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
                    LayoutBuilder(
                      builder: (context, headerConstraints) {
                        final stackHeader = headerConstraints.maxWidth < 760;
                        final intro = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PERSONAL TRIP STUDIO',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.8,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Build your next trip',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontSize: stackHeader ? 36 : 44,
                                      height: 1.05,
                                      fontWeight: FontWeight.w700,
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
                        );
                        // The generate action now lives at the foot of the
                        // setup card, next to the fields it depends on.
                        return intro;
                      },
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
                      destinationSelector: DestinationSelector(
                        destinations: _destinations,
                        selectedId: _selectedDestinationId,
                        onSelected: _selectDestination,
                        onAdd: _addDestination,
                        travelLegs: _travelLegs,
                        onEditTravelLeg: _editTravelLeg,
                        onRemove: _removeDestination,
                        onEdit: _editDestination,
                        embedded: true,
                      ),
                      budgetController: budgetController,
                      titleController: tripTitleController,
                      dateLabel: _dateLabel(),
                      travelers: travelers,
                      currencyCode: currencyCode,
                      onCurrencyChanged: _setCurrency,
                      onPickDates: _pickDates,
                      onTravelersChanged: (value) =>
                          setState(() => travelers = value),
                      missingSetup: _missingTripSetup,
                      isGenerating: isGenerating,
                      planGenerated: planGenerated,
                      onGenerate: _generatePlan,
                    ),
                    if (_destinations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _AreaPlanningCard(
                        area: _selectedDestination.mapSearchArea,
                        destination: destinationController.text.trim(),
                        enabled: _mapService != null && !isGenerating,
                        onConfigure: _chooseMapArea,
                        onClear: _clearMapArea,
                      ),
                      const SizedBox(height: 20),
                      _HotelStayCard(
                        recommendations: hotelRecommendations,
                        selectedHotel: selectedHotel,
                        onSelected: _selectRecommendedHotel,
                        onEdit: _editHotel,
                        currencyCode: currencyCode,
                      ),
                      const SizedBox(height: 20),
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _DestinationMap(
                                destinationId: _selectedDestinationId,
                                result: plannerResult,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 430,
                                child: AiChatWidget(
                                  onPropose: _proposeAiChange,
                                  onApply: _applyAiCommand,
                                  onUndo: _undoAiChange,
                                  canUndo: _canUndoAiChange,
                                  liveAiEnabled:
                                      AppConfig.aiAssistantUrl.isNotEmpty,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _DestinationMap(
                          destinationId: _selectedDestinationId,
                          result: plannerResult,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 430,
                          child: AiChatWidget(
                            onPropose: _proposeAiChange,
                            onApply: _applyAiCommand,
                            onUndo: _undoAiChange,
                            canUndo: _canUndoAiChange,
                            liveAiEnabled: AppConfig.aiAssistantUrl.isNotEmpty,
                          ),
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
                        onManual: _openManualPlanner,
                        onPriceDisplayModeChanged: _setPriceDisplayMode,
                        currencyCode: currencyCode,
                        onReview: () {
                          _persistSelectedDestination();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SummaryPage(
                                destinations: List.unmodifiable(_destinations),
                                travelers: travelers,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
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

class _AiUndoSnapshot {
  const _AiUndoSnapshot({
    required this.destinationId,
    required this.result,
    required this.budgetText,
    required this.selectedPlan,
    required this.hotelRecommendations,
    required this.selectedHotel,
    required this.placeDataSource,
    required this.planGenerated,
  });

  final String destinationId;
  final PlannerResult? result;
  final String budgetText;
  final String selectedPlan;
  final List<HotelStay> hotelRecommendations;
  final HotelStay? selectedHotel;
  final String placeDataSource;
  final bool planGenerated;
}

class _PendingAiChoice {
  const _PendingAiChoice({
    required this.command,
    this.choices = const [],
    this.awaitingDay = false,
    this.awaitingScheduleDay = false,
  });

  final TripAiCommand command;
  final List<String> choices;
  final bool awaitingDay;
  final bool awaitingScheduleDay;
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

    final preferenceLabels = preference!.styleTags;

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
  final Widget destinationSelector;
  final TextEditingController budgetController;
  final TextEditingController titleController;
  final String dateLabel;
  final int travelers;
  final String currencyCode;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onPickDates;
  final ValueChanged<int> onTravelersChanged;

  /// What the form is still waiting for. Empty means the plan can be
  /// generated; otherwise the card says what is missing instead of leaving an
  /// empty space where the button would be.
  final List<String> missingSetup;
  final bool isGenerating;
  final bool planGenerated;
  final VoidCallback onGenerate;

  const _TripSetupCard({
    required this.destinationSelector,
    required this.budgetController,
    required this.titleController,
    required this.dateLabel,
    required this.travelers,
    required this.currencyCode,
    required this.onCurrencyChanged,
    required this.onPickDates,
    required this.onTravelersChanged,
    required this.missingSetup,
    required this.isGenerating,
    required this.planGenerated,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final theme = Theme.of(context);

          // These controls are three different widget types - an
          // OutlinedButton, a TextField and a bordered Container - so each one
          // inherited its own shape: a stadium pill, an 18px input border and a
          // 14px container, at two different heights. Nothing here decides
          // that on its own any more.
          const fieldHeight = 56.0;
          final fieldRadius = BorderRadius.circular(18);
          final fieldBorder = BorderSide(color: theme.dividerColor, width: 1.2);
          final fieldFill =
              theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface;
          final fieldButtonStyle = OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, fieldHeight),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: fieldFill,
            side: fieldBorder,
            shape: RoundedRectangleBorder(borderRadius: fieldRadius),
          );

          /// A TextField grows with its content padding, so it has to be told
          /// the height the buttons already have.
          Widget boxedField(Widget child) =>
              SizedBox(height: fieldHeight, child: child);

          final destinationField = _LabeledField(
            label: 'Destinations',
            child: destinationSelector,
          );
          final titleField = _LabeledField(
            label: 'Trip name',
            child: TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Da Nang weekend',
                prefixIcon: Icon(Icons.bookmark_outline_rounded),
              ),
            ),
          );
          final detailFields = [
            _LabeledField(
              label: 'Travel dates',
              child: boxedField(
                OutlinedButton.icon(
                  onPressed: onPickDates,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(dateLabel),
                  ),
                  style: fieldButtonStyle,
                ),
              ),
            ),
            _LabeledField(
              label: 'Total budget (all travelers)',
              // Sized by the same Container as the Travelers field rather
              // than by InputDecoration. Letting the decorator draw its own
              // box put this control at a different height twice: it sizes to
              // its content, and neither a SizedBox around the TextField nor
              // InputDecoration.constraints reliably overrode that. The
              // TextField here is stripped of every border and fill so the
              // Container is the only thing painting.
              child: _FieldBox(
                height: fieldHeight,
                radius: fieldRadius,
                border: fieldBorder,
                fill: fieldFill,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: budgetController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          // The theme sets these individually, so clearing
                          // `border` alone would leave them drawing.
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: '2,500',
                          prefixText: '${Money.symbolFor(currencyCode)} ',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _LabeledField(
              label: 'Currency',
              child: boxedField(
                CurrencyField(
                  code: currencyCode,
                  onChanged: onCurrencyChanged,
                  style: fieldButtonStyle,
                ),
              ),
            ),
            _LabeledField(
              label: 'Travelers',
              child: _FieldBox(
                height: fieldHeight,
                radius: fieldRadius,
                border: fieldBorder,
                fill: fieldFill,
                padding: const EdgeInsets.symmetric(horizontal: 4),
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

          // Every field shows from the start. Hiding dates, budget, currency
          // and travellers until a destination existed made the form look
          // like it had two steps when it has one.
          final Widget layout;
          if (!wide) {
            layout = Column(
              children: [titleField, destinationField, ...detailFields]
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: field,
                    ),
                  )
                  .toList(),
            );
          } else {
            layout = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleField,
                const SizedBox(height: 14),
                destinationField,
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < detailFields.length; i++) ...[
                      Expanded(child: detailFields[i]),
                      if (i != detailFields.length - 1)
                        const SizedBox(width: 14),
                    ],
                  ],
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              layout,
              const SizedBox(height: 20),
              if (missingSetup.isEmpty)
                Align(
                  alignment: wide
                      ? Alignment.centerRight
                      : Alignment.center,
                  child: SizedBox(
                    width: wide ? null : double.infinity,
                    child: FilledButton.icon(
                      onPressed: isGenerating ? null : onGenerate,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        isGenerating
                            ? 'Generating...'
                            : planGenerated
                            ? 'Regenerate schedule'
                            : 'Generate schedule',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add ${_readableList(missingSetup)} to generate a plan.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A form control drawn as a plain box, with the focus ring Material would
/// normally give an input.
///
/// The setup row's controls share one Container-based box so they all match.
/// That cost the TextField its focus highlight, which this puts back: while
/// anything inside has focus the border thickens and takes the primary colour,
/// matching the theme's own focusedBorder.
/// "a, b and c" - so the missing-fields line reads as a sentence.
String _readableList(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.take(items.length - 1).join(', ')} and ${items.last}';
}

class _FieldBox extends StatelessWidget {
  final double height;
  final BorderRadius radius;
  final BorderSide border;
  final Color fill;
  final EdgeInsets padding;
  final Widget child;

  const _FieldBox({
    required this.height,
    required this.radius,
    required this.border,
    required this.fill,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      // An observer, not a stop in the tab order - the controls inside keep
      // their own place in it.
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final side = focused
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2.2,
                )
              : border;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              border: Border.fromBorderSide(side),
              borderRadius: radius,
            ),
            child: child,
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _AreaPlanningCard extends StatelessWidget {
  const _AreaPlanningCard({
    required this.area,
    required this.destination,
    required this.enabled,
    required this.onConfigure,
    required this.onClear,
  });

  final MapSearchArea? area;
  final String destination;
  final bool enabled;
  final VoidCallback onConfigure;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final configured = area != null;

    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAP-LED PLANNING',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                configured
                    ? 'Your travel zone is ready'
                    : 'Choose exactly where you want to explore',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                configured
                    ? 'The next schedule will use only verified places inside the ${area!.radiusLabel} circle.'
                    : 'Draw a circle around part of $destination. The planner will discover places inside it, rank them, and build an efficient route.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (configured) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.radio_button_checked, size: 18),
                      label: Text('${area!.radiusLabel} radius'),
                    ),
                    const Chip(
                      avatar: Icon(Icons.filter_alt_outlined, size: 18),
                      label: Text('Preferences applied'),
                    ),
                    const Chip(
                      avatar: Icon(Icons.route_outlined, size: 18),
                      label: Text('Route optimized'),
                    ),
                  ],
                ),
              ],
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: enabled ? onConfigure : null,
                icon: Icon(
                  configured
                      ? Icons.edit_location_alt_outlined
                      : Icons.gesture_rounded,
                ),
                label: Text(configured ? 'Edit travel zone' : 'Draw on map'),
              ),
              if (configured)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Use whole city'),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 18), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  size: 34,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: copy),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HotelStayCard extends StatelessWidget {
  final List<HotelStay> recommendations;
  final HotelStay? selectedHotel;
  final ValueChanged<HotelStay> onSelected;
  final VoidCallback onEdit;
  final String currencyCode;

  const _HotelStayCard({
    required this.recommendations,
    required this.selectedHotel,
    required this.onSelected,
    required this.onEdit,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedHotel;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hotel_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Hotel and daily route anchor',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(selected == null ? 'Enter my hotel' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recommendations.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue:
                  recommendations.any((hotel) => hotel.id == selected?.id)
                  ? selected?.id
                  : null,
              decoration: const InputDecoration(
                labelText: 'Recommended Google hotels',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.recommend_outlined),
              ),
              items: recommendations
                  .map(
                    (hotel) => DropdownMenuItem(
                      value: hotel.id,
                      child: Text(
                        '${hotel.name} • ${hotel.rating.toStringAsFixed(1)}★',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                onSelected(
                  recommendations.firstWhere((hotel) => hotel.id == id),
                );
              },
            ),
          if (recommendations.isNotEmpty) const SizedBox(height: 12),
          if (selected == null)
            const Text(
              'Generate a destination plan for recommendations, or enter the hotel you already booked.',
            )
          else
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text(
                  selected.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('${selected.nights} nights'),
                Text('${selected.rooms} rooms'),
                Text(
                  selected.nightlyRate > 0
                      ? '${selected.nightlyRateEstimated ? 'Estimated ' : ''}'
                            '${Money.format(selected.nightlyRate, currencyCode)} / room / night'
                      : 'Nightly price not entered',
                ),
                Text(
                  'Accommodation total: '
                  '${Money.format(selected.totalCost, currencyCode)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Each day starts and ends here. Hotel prices are user-entered estimates, not live booking rates.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotelEditorDialog extends StatefulWidget {
  final HotelStay? initial;
  final int defaultNights;
  final int defaultRooms;
  final MapService? mapService;
  final String currencyCode;

  const _HotelEditorDialog({
    required this.initial,
    required this.defaultNights,
    required this.defaultRooms,
    required this.mapService,
    required this.currencyCode,
  });

  @override
  State<_HotelEditorDialog> createState() => _HotelEditorDialogState();
}

class _HotelEditorDialogState extends State<_HotelEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final addressController = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  late final rateController = TextEditingController(
    text: widget.initial == null || widget.initial!.nightlyRate <= 0
        ? ''
        : widget.initial!.nightlyRate.toStringAsFixed(0),
  );
  late final nightsController = TextEditingController(
    text: '${widget.initial?.nights ?? widget.defaultNights}',
  );
  late final roomsController = TextEditingController(
    text: '${widget.initial?.rooms ?? widget.defaultRooms}',
  );
  bool saving = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    rateController.dispose();
    nightsController.dispose();
    roomsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      var latitude = widget.initial?.latitude ?? 0;
      var longitude = widget.initial?.longitude ?? 0;
      final addressChanged =
          addressController.text.trim() != widget.initial?.address.trim();
      if (addressChanged || (latitude == 0 && longitude == 0)) {
        final service = widget.mapService;
        if (service == null) {
          throw Exception(
            'A Google Maps key is required to locate this hotel.',
          );
        }
        final coordinates = await service.geocodeAddress(
          addressController.text.trim(),
        );
        latitude = coordinates.latitude;
        longitude = coordinates.longitude;
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        HotelStay(
          id:
              widget.initial?.id ??
              'custom-hotel-${DateTime.now().millisecondsSinceEpoch}',
          name: nameController.text.trim(),
          address: addressController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          rating: widget.initial?.rating ?? 0,
          nightlyRate: double.parse(rateController.text.trim()),
          nights: int.parse(nightsController.text.trim()),
          rooms: int.parse(roomsController.text.trim()),
          userProvided: true,
          nightlyRateEstimated: false,
        ),
      );
    } catch (exception) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not locate the hotel. Check the address. $exception';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hotel details'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Hotel name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the hotel name.'
                      : null,
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Full address'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an address so routes can start here.'
                      : null,
                ),
                TextFormField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Price per room per night',
                    prefixText: '${Money.symbolFor(widget.currencyCode)} ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || amount < 0
                        ? 'Enter a valid nightly price.'
                        : null;
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: nightsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Nights'),
                        validator: _positiveInteger,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: roomsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Rooms'),
                        validator: _positiveInteger,
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Locating...' : 'Save hotel'),
        ),
      ],
    );
  }

  static String? _positiveInteger(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? 'Enter 1 or more.' : null;
  }
}

class _DestinationMap extends StatefulWidget {
  final String destinationId;
  final PlannerResult? result;

  /// Full screen drops the panel, the fixed height and the expand button.
  final bool fullscreen;

  const _DestinationMap({
    required this.destinationId,
    required this.result,
    this.fullscreen = false,
  });

  @override
  State<_DestinationMap> createState() => _DestinationMapState();
}

class _DestinationMapState extends State<_DestinationMap> {
  final LayerHitNotifier<int> _routeHitNotifier = ValueNotifier(null);
  final MapController _mapController = MapController();
  final Map<int, List<LatLng>> _walkingRoutes = {};
  bool _isLoadingRoutes = false;
  bool _routeFallbackUsed = false;
  String _loadedSignature = '';
  int? _highlightedDay;
  bool _hotelHighlighted = false;

  static const _fallbackCenter = LatLng(35.6762, 139.6503);

  /// Walking routes cost one Google Routes call per day, so they are cached by
  /// itinerary signature and shared across instances. Opening the map full
  /// screen builds a second [_DestinationMap]; without this it would re-fetch
  /// every day's route and show the spinner again.
  static final Map<String, Map<int, List<LatLng>>> _routeCache = {};
  static final Set<String> _fallbackSignatures = {};

  @override
  void initState() {
    super.initState();
    _scheduleRouteLoad();
  }

  @override
  void didUpdateWidget(covariant _DestinationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged =
        _resultSignatureFor(oldWidget.destinationId, oldWidget.result) !=
        _resultSignature();
    if (routeChanged) {
      _highlightedDay = null;
      _hotelHighlighted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitFullRoute();
      });
    }
    _scheduleRouteLoad();
  }

  @override
  void dispose() {
    _routeHitNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _highlightDay(int? dayNumber) {
    if ((_highlightedDay == dayNumber && !_hotelHighlighted) || !mounted) {
      return;
    }
    setState(() {
      _highlightedDay = dayNumber;
      _hotelHighlighted = false;
    });
  }

  void _highlightHotel(bool highlighted) {
    if (_hotelHighlighted == highlighted || !mounted) return;
    setState(() {
      _hotelHighlighted = highlighted;
      if (highlighted) _highlightedDay = null;
    });
  }

  void _scheduleRouteLoad() {
    final signature = _resultSignature();
    if (signature == _loadedSignature) return;
    _loadedSignature = signature;

    final cached = _routeCache[signature];
    if (cached != null) {
      _walkingRoutes
        ..clear()
        ..addAll(cached);
      _routeFallbackUsed = _fallbackSignatures.contains(signature);
      _isLoadingRoutes = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWalkingRoutes());
  }

  String _resultSignature() {
    return _resultSignatureFor(widget.destinationId, widget.result);
  }

  String _resultSignatureFor(String destinationId, PlannerResult? result) {
    final hotelId = result?.hotel?.id ?? 'no-hotel';
    final places = (result?.days ?? const <PlannerDay>[])
        .expand((day) => day.places)
        .map(
          (item) =>
              '${item.place.id}:${item.place.latitude}:${item.place.longitude}',
        )
        .join('|');
    return '$destinationId|$hotelId|$places';
  }

  List<LatLng> _resultPoints() {
    final result = widget.result;
    final hotel = result?.hotel;
    return [
      if (hotel != null) LatLng(hotel.latitude, hotel.longitude),
      ...(result?.days ?? const <PlannerDay>[])
          .expand((day) => day.places)
          .map((item) => LatLng(item.place.latitude, item.place.longitude)),
    ];
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Route map')),
          body: _DestinationMap(
            destinationId: widget.destinationId,
            result: widget.result,
            fullscreen: true,
          ),
        ),
      ),
    );
  }

  void _fitFullRoute() {
    final points = _resultPoints();
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(55),
        maxZoom: 15,
      ),
    );
  }

  Future<void> _loadWalkingRoutes() async {
    final days = widget.result?.days ?? const <PlannerDay>[];
    if (!AppConfig.hasGoogleMapsApiKey || days.isEmpty) {
      if (mounted) {
        setState(() {
          _walkingRoutes.clear();
          _routeFallbackUsed = days.isNotEmpty;
          _isLoadingRoutes = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingRoutes = true;
      _routeFallbackUsed = false;
      _walkingRoutes.clear();
    });
    final service = MapService(apiKey: AppConfig.googleMapsApiKey);
    final hotel = widget.result?.hotel;
    final loadedRoutes = <int, List<LatLng>>{};
    var fallbackUsed = false;

    await Future.wait(
      days
          .where(
            (day) =>
                hotel == null ? day.places.length > 1 : day.places.isNotEmpty,
          )
          .map((day) async {
            try {
              final stops = <Coordinates>[
                if (hotel != null)
                  Coordinates(
                    latitude: hotel.latitude,
                    longitude: hotel.longitude,
                  ),
                ...day.places.map(
                  (item) => Coordinates(
                    latitude: item.place.latitude,
                    longitude: item.place.longitude,
                  ),
                ),
                if (hotel != null)
                  Coordinates(
                    latitude: hotel.latitude,
                    longitude: hotel.longitude,
                  ),
              ];
              final route = await service.getWalkingRoute(stops);
              loadedRoutes[day.dayNumber] = route
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList();
            } catch (_) {
              fallbackUsed = true;
            }
          }),
    );

    _routeCache[_loadedSignature] = Map<int, List<LatLng>>.from(loadedRoutes);
    if (fallbackUsed) {
      _fallbackSignatures.add(_loadedSignature);
    } else {
      _fallbackSignatures.remove(_loadedSignature);
    }

    if (!mounted || _resultSignature() != _loadedSignature) return;
    setState(() {
      _walkingRoutes.addAll(loadedRoutes);
      _routeFallbackUsed = fallbackUsed;
      _isLoadingRoutes = false;
    });
  }

  Color _dayColor(BuildContext context, int dayNumber) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.deepOrange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    return colors[(dayNumber - 1) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.result?.days ?? const <PlannerDay>[];
    final hotel = widget.result?.hotel;
    final points = _resultPoints();
    final mapOptions = points.length > 1
        ? MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(55),
              maxZoom: 15,
            ),
          )
        : MapOptions(
            initialCenter: points.isEmpty ? _fallbackCenter : points.single,
            initialZoom: points.isEmpty ? 10 : 14,
          );
    final routeDays = days
        .where(
          (day) =>
              hotel == null ? day.places.length > 1 : day.places.isNotEmpty,
        )
        .toList();
    routeDays.sort((a, b) {
      if (a.dayNumber == _highlightedDay) return 1;
      if (b.dayNumber == _highlightedDay) return -1;
      return a.dayNumber.compareTo(b.dayNumber);
    });
    final markerDays = List<PlannerDay>.of(days)
      ..sort((a, b) {
        if (a.dayNumber == _highlightedDay) return 1;
        if (b.dayNumber == _highlightedDay) return -1;
        return a.dayNumber.compareTo(b.dayNumber);
      });
    final highlightedRoute = _highlightedDay == null
        ? null
        : routeDays
              .where((day) => day.dayNumber == _highlightedDay)
              .firstOrNull;

    // Inline, the map keeps the panel, its fixed height and rounded corners.
    // Full screen it fills the page, so that chrome comes off.
    Widget frame(Widget map) => widget.fullscreen
        ? map
        : _Panel(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 430,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: map,
              ),
            ),
          );

    return frame(
      Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              key: ValueKey(
                points
                    .map((point) => '${point.latitude},${point.longitude}')
                    .join('|'),
              ),
              mapController: _mapController,
              options: mapOptions,
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.travelplanner.travel',
                  maxNativeZoom: 19,
                ),
                TranslucentPointer(
                  child: MouseRegion(
                    hitTestBehavior: HitTestBehavior.deferToChild,
                    cursor: SystemMouseCursors.click,
                    onHover: (_) {
                      final hit = _routeHitNotifier.value;
                      if (hit != null && hit.hitValues.isNotEmpty) {
                        _highlightDay(hit.hitValues.first);
                      }
                    },
                    onExit: (_) => _highlightDay(null),
                    child: PolylineLayer<int>(
                      hitNotifier: _routeHitNotifier,
                      minimumHitbox: 20,
                      polylines: [
                        for (final day in routeDays)
                          Polyline<int>(
                            points:
                                _walkingRoutes[day.dayNumber] ??
                                <LatLng>[
                                  if (hotel != null)
                                    LatLng(hotel.latitude, hotel.longitude),
                                  ...day.places.map(
                                    (item) => LatLng(
                                      item.place.latitude,
                                      item.place.longitude,
                                    ),
                                  ),
                                  if (hotel != null)
                                    LatLng(hotel.latitude, hotel.longitude),
                                ],
                            color: _dayColor(context, day.dayNumber)
                                .withValues(
                                  alpha:
                                      _hotelHighlighted ||
                                          _highlightedDay == null ||
                                          _highlightedDay == day.dayNumber
                                      ? 1
                                      : 0.18,
                                ),
                            strokeWidth: _hotelHighlighted
                                ? 7
                                : _highlightedDay == day.dayNumber
                                ? 8
                                : 4,
                            borderColor: Colors.white,
                            borderStrokeWidth:
                                _hotelHighlighted ||
                                    _highlightedDay == day.dayNumber
                                ? 3
                                : 1,
                            hitValue: day.dayNumber,
                          ),
                      ],
                    ),
                  ),
                ),
                if (highlightedRoute != null && !_hotelHighlighted)
                  TranslucentPointer(
                    child: PolylineLayer<int>(
                      polylines: [
                        Polyline<int>(
                          points:
                              _walkingRoutes[highlightedRoute.dayNumber] ??
                              <LatLng>[
                                if (hotel != null)
                                  LatLng(hotel.latitude, hotel.longitude),
                                ...highlightedRoute.places.map(
                                  (item) => LatLng(
                                    item.place.latitude,
                                    item.place.longitude,
                                  ),
                                ),
                                if (hotel != null)
                                  LatLng(hotel.latitude, hotel.longitude),
                              ],
                          color: _dayColor(
                            context,
                            highlightedRoute.dayNumber,
                          ),
                          strokeWidth: 9,
                          borderColor: Colors.white,
                          borderStrokeWidth: 4,
                          hitValue: highlightedRoute.dayNumber,
                        ),
                      ],
                    ),
                  ),
                MarkerLayer(
                  markers: [
                    for (final day in markerDays)
                      for (
                        int stopIndex = 0;
                        stopIndex < day.places.length;
                        stopIndex++
                      )
                        Marker(
                          point: LatLng(
                            day.places[stopIndex].place.latitude,
                            day.places[stopIndex].place.longitude,
                          ),
                          width: 54,
                          height: 54,
                          alignment: Alignment.topCenter,
                          child: Tooltip(
                            message:
                                'Day ${day.dayNumber}, stop ${stopIndex + 1}: '
                                '${day.places[stopIndex].place.name}',
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => _highlightDay(day.dayNumber),
                              onExit: (_) {
                                if (_highlightedDay == day.dayNumber) {
                                  _highlightDay(null);
                                }
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 140),
                                opacity:
                                    _hotelHighlighted ||
                                        _highlightedDay == null ||
                                        _highlightedDay == day.dayNumber
                                    ? 1
                                    : 0.28,
                                child: AnimatedScale(
                                  duration: const Duration(
                                    milliseconds: 140,
                                  ),
                                  scale: _highlightedDay == day.dayNumber
                                      ? 1.25
                                      : 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _dayColor(
                                        context,
                                        day.dayNumber,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width:
                                            _highlightedDay == day.dayNumber
                                            ? 4
                                            : 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${day.dayNumber}.${stopIndex + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
                if (hotel != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(hotel.latitude, hotel.longitude),
                        width: _hotelHighlighted ? 78 : 66,
                        height: _hotelHighlighted ? 78 : 66,
                        alignment: Alignment.topCenter,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => _highlightHotel(true),
                          onExit: (_) => _highlightHotel(false),
                          child: Tooltip(
                            message:
                                'Hotel: ${hotel.name} • all daily routes',
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 140),
                              scale: _hotelHighlighted ? 1.18 : 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: _hotelHighlighted ? 6 : 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: _hotelHighlighted
                                            ? 0.45
                                            : 0.26,
                                      ),
                                      blurRadius: _hotelHighlighted
                                          ? 14
                                          : 6,
                                      spreadRadius: _hotelHighlighted
                                          ? 3
                                          : 0,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.hotel_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Chip(
              avatar: const Icon(Icons.location_searching, size: 18),
              label: Text(
                points.isEmpty
                    ? 'Destination map'
                    : '${points.length} itinerary stops',
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          if (!widget.fullscreen)
            Positioned(
              top: 16,
              right: 16,
              child: Tooltip(
                message: 'Open the map full screen',
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  child: IconButton(
                    onPressed: _openFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                ),
              ),
            ),
          if (_isLoadingRoutes)
            const Positioned(
              top: 20,
              right: 76,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 7),
                      Text('Loading walking routes...'),
                    ],
                  ),
                ),
              ),
            )
          else if (_hotelHighlighted)
            Positioned(
              top: 20,
              right: 76,
              child: Card(
                color: Theme.of(context).colorScheme.primary,
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Text(
                    'All hotel routes highlighted',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            )
          else if (_highlightedDay != null)
            Positioned(
              top: 20,
              right: 76,
              child: Card(
                color: _dayColor(context, _highlightedDay!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Text(
                    'Day $_highlightedDay highlighted',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            )
          else if (_routeFallbackUsed)
            const Positioned(
              top: 20,
              right: 76,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text('Route API unavailable • showing stop order'),
                ),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.88),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),
          if (points.isNotEmpty)
            Positioned(
              left: 14,
              bottom: 14,
              child: Tooltip(
                message: 'Return to the full itinerary route',
                child: FilledButton.icon(
                  onPressed: _fitFullRoute,
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  label: const Text('Back to route'),
                ),
              ),
            ),
        ],
      ),
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
        '3 activities + 3 meals',
        'Nearby favorites • more free time',
        Icons.spa_outlined,
      ),
      (
        'Balanced',
        '4 activities + 3 meals',
        'Balanced variety, value, and travel',
        Icons.balance_outlined,
      ),
      (
        'Explorer',
        '6 activities + 3 meals',
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
                                  ).dividerColor.withValues(alpha: 0.82),
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

class _ManualPlannerDialog extends StatefulWidget {
  final PlannerResult result;

  const _ManualPlannerDialog({required this.result});

  @override
  State<_ManualPlannerDialog> createState() => _ManualPlannerDialogState();
}

class _ManualPlannerDialogState extends State<_ManualPlannerDialog> {
  final searchController = TextEditingController();
  late final List<PlannerDay> days = widget.result.days
      .map(
        (day) => PlannerDay(
          dayNumber: day.dayNumber,
          places: List<ScoredPlace>.of(day.places),
        ),
      )
      .toList();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Set<String> get _usedPlaceIds =>
      days.expand((day) => day.places).map((item) => item.place.id).toSet();

  List<ScoredPlace> get _availablePlaces {
    final query = searchController.text.trim().toLowerCase();
    final used = _usedPlaceIds;
    return widget.result.rankedPlaces.where((item) {
      if (used.contains(item.place.id)) return false;
      if (query.isEmpty) return true;
      return item.place.name.toLowerCase().contains(query) ||
          item.place.category.toLowerCase().contains(query);
    }).toList();
  }

  void _addPlace(ScoredPlace place, int dayIndex) {
    setState(() => days[dayIndex].places.add(place));
  }

  void _removePlace(int dayIndex, int stopIndex) {
    setState(() => days[dayIndex].places.removeAt(stopIndex));
  }

  void _movePlace(int dayIndex, int stopIndex, int offset) {
    final nextIndex = stopIndex + offset;
    if (nextIndex < 0 || nextIndex >= days[dayIndex].places.length) return;
    setState(() {
      final item = days[dayIndex].places.removeAt(stopIndex);
      days[dayIndex].places.insert(nextIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_calendar_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create itinerary manually',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Add places to any day, then reorder them into the sequence you want.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final available = _AvailableManualPlaces(
                      searchController: searchController,
                      places: _availablePlaces,
                      dayCount: days.length,
                      onSearchChanged: (_) => setState(() {}),
                      onAdd: _addPlace,
                    );
                    final itinerary = _ManualDayEditor(
                      days: days,
                      onRemove: _removePlace,
                      onMove: _movePlace,
                    );
                    if (compact) {
                      return Column(
                        children: [
                          Expanded(child: available),
                          const Divider(height: 24),
                          Expanded(child: itinerary),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: available),
                        const VerticalDivider(width: 28),
                        Expanded(child: itinerary),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, days),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use manual plan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableManualPlaces extends StatelessWidget {
  final TextEditingController searchController;
  final List<ScoredPlace> places;
  final int dayCount;
  final ValueChanged<String> onSearchChanged;
  final void Function(ScoredPlace place, int dayIndex) onAdd;

  const _AvailableManualPlaces({
    required this.searchController,
    required this.places,
    required this.dayCount,
    required this.onSearchChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available places (${places.length})',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search name or category',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: places.isEmpty
              ? const Center(child: Text('No unused places match this search.'))
              : ListView.separated(
                  itemCount: places.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = places[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item.place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item.place.category} • '
                          '${item.place.estimatedVisitMinutes} min',
                        ),
                        trailing: PopupMenuButton<int>(
                          tooltip: 'Add to day',
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onSelected: (dayIndex) => onAdd(item, dayIndex),
                          itemBuilder: (context) => List.generate(
                            dayCount,
                            (dayIndex) => PopupMenuItem(
                              value: dayIndex,
                              child: Text('Add to Day ${dayIndex + 1}'),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ManualDayEditor extends StatelessWidget {
  final List<PlannerDay> days;
  final void Function(int dayIndex, int stopIndex) onRemove;
  final void Function(int dayIndex, int stopIndex, int offset) onMove;

  const _ManualDayEditor({
    required this.days,
    required this.onRemove,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your days', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: days.length,
            itemBuilder: (context, dayIndex) {
              final day = days[dayIndex];
              return Card(
                child: ExpansionTile(
                  initiallyExpanded: dayIndex < 2,
                  title: Text(
                    'Day ${day.dayNumber} • ${day.places.length} stops',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  children: day.places.isEmpty
                      ? const [
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('No places added yet.'),
                            ),
                          ),
                        ]
                      : List.generate(day.places.length, (stopIndex) {
                          final item = day.places[stopIndex];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              child: Text('${stopIndex + 1}'),
                            ),
                            title: Text(item.place.name),
                            subtitle: Text(item.place.category),
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  tooltip: 'Move earlier',
                                  onPressed: stopIndex == 0
                                      ? null
                                      : () => onMove(dayIndex, stopIndex, -1),
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Move later',
                                  onPressed: stopIndex == day.places.length - 1
                                      ? null
                                      : () => onMove(dayIndex, stopIndex, 1),
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () =>
                                      onRemove(dayIndex, stopIndex),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlanPreview extends StatelessWidget {
  final bool generated;
  final String selectedPlan;
  final String destination;
  final PlannerResult? result;
  final String placeDataSource;
  final VoidCallback onManual;
  final VoidCallback onReview;
  final ValueChanged<PriceDisplayMode> onPriceDisplayModeChanged;
  final String currencyCode;

  const _PlanPreview({
    required this.generated,
    required this.selectedPlan,
    required this.destination,
    required this.result,
    required this.placeDataSource,
    required this.onManual,
    required this.onReview,
    required this.onPriceDisplayModeChanged,
    required this.currencyCode,
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
            // No action here. This button called onManual, which generates
            // a plan and then opens the manual editor - the same two steps as
            // generating from the setup card and then using the button below,
            // which already reads "Create manually" for an empty plan.
          ] else ...[
            _RankingSummary(result: result!),
            const SizedBox(height: 18),
            _BudgetAllocationSummary(
              result: result!,
              currencyCode: currencyCode,
            ),
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
                  hotel: result!.hotel,
                  startTimeOverrides: result!.startTimeOverrides,
                ),
                if (i != result!.days.length - 1) const Divider(height: 32),
              ],
            const Divider(height: 32),
            _TotalExpenseSummary(
              result: result!,
              onPriceDisplayModeChanged: onPriceDisplayModeChanged,
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onManual,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(
                      result!.days.every((day) => day.places.isEmpty)
                          ? 'Create manually'
                          : 'Edit manually',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: result!.validation.isValid ? onReview : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Review final plan'),
                  ),
                ],
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

  /// The currency currently selected in the form. The budget is the number the
  /// user typed, and that number is always denominated in whatever currency is
  /// selected now - so it must not be rendered with a stale plan's symbol.
  final String currencyCode;

  const _BudgetAllocationSummary({
    required this.result,
    required this.currencyCode,
  });

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
                'Budget allocation • '
                '${Money.format(allocation.total, currencyCode)} total',
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
                      '${category.$1}: '
                      '${Money.format(category.$2, currencyCode)}',
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Meals use the food allocation '
            '(${Money.format(allocation.dailyFoodBudget(result.days.length), currencyCode)} per day); '
            'attractions use the activities allocation '
            '(${Money.format(allocation.dailyActivitiesBudget(result.days.length), currencyCode)} per day).',
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
  final ValueChanged<PriceDisplayMode> onPriceDisplayModeChanged;

  const _TotalExpenseSummary({
    required this.result,
    required this.onPriceDisplayModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onContainer = Theme.of(context).colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only the headline row opens the breakdown. The toggle sits outside
          // that tap target so choosing a mode never opens the page by
          // accident.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              onTap: () => showCostBreakdown(context, result),
              child: _headline(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Show as',
                    style: TextStyle(
                      color: onContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SegmentedButton<PriceDisplayMode>(
                  segments: const [
                    ButtonSegment(
                      value: PriceDisplayMode.perPerson,
                      label: Text('Per person'),
                      icon: Icon(Icons.person_outline_rounded),
                    ),
                    ButtonSegment(
                      value: PriceDisplayMode.total,
                      label: Text('Total'),
                      icon: Icon(Icons.groups_outlined),
                    ),
                  ],
                  selected: {result.priceDisplayMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      onPriceDisplayModeChanged(selection.first),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headline(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Icon(
            Icons.payments_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total estimated trip expense • ${result.priceModeSuffix}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap to see how this is calculated',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            Money.format(result.totalEstimatedTripCost, result.currencyCode),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
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
  final HotelStay? hotel;
  final Map<String, int> startTimeOverrides;
  const _GeneratedDayPreview({
    required this.day,
    required this.targetMinutes,
    required this.restMinutes,
    required this.hotel,
    required this.startTimeOverrides,
  });

  @override
  Widget build(BuildContext context) {
    final scheduledStops = const DailyTimeScheduleService().schedule(
      day.places,
      startTimeOverrides: startTimeOverrides,
    );
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
              else ...[
                if (hotel != null)
                  _HotelRouteEndpoint(
                    time: _formatStartTime(
                      scheduledStops.isEmpty
                          ? 7 * 60 + 30
                          : (scheduledStops.first.startMinutes - 30).clamp(
                              0,
                              1439,
                            ),
                    ),
                    label: 'Start at ${hotel!.name}',
                  ),
                for (
                  int stopIndex = 0;
                  stopIndex < day.places.length;
                  stopIndex++
                )
                  Builder(
                    builder: (context) {
                      final scheduled = scheduledStops[stopIndex];
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PlacePhoto(
                              placeName: day.places[stopIndex].place.name,
                              photoUrls: day.places[stopIndex].place.photoUrls,
                              width: 72,
                              height: 72,
                              borderRadius: 14,
                            ),
                            const SizedBox(width: 12),
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
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _StopMetadataBadge(
                                        icon: Icons.schedule_rounded,
                                        text: scheduled.formattedStartTime,
                                      ),
                                      _StopMetadataBadge(
                                        icon: Icons.category_outlined,
                                        text: scheduled.roleLabel,
                                      ),
                                      Text(
                                        '${day.places[stopIndex].place.category.replaceAll('_', ' ')} • '
                                        '${day.places[stopIndex].place.estimatedVisitMinutes} min • '
                                        'score ${day.places[stopIndex].totalScore.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.84),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // No per-stop price. One total for the trip, with
                            // the full derivation a tap away, beats a column of
                            // figures that are mostly estimates anyway.
                          ],
                        ),
                      );
                    },
                  ),
                if (hotel != null)
                  _HotelRouteEndpoint(
                    time: 'End',
                    label: 'Return to ${hotel!.name}',
                  ),
              ],
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
              const SizedBox(height: 4),
              Text(
                'Planned activity time: '
                '${_formatMinutes(day.estimatedActivityMinutes)} / '
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

  String _formatStartTime(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }
}

class _HotelRouteEndpoint extends StatelessWidget {
  final String time;
  final String label;

  const _HotelRouteEndpoint({required this.time, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(
              Icons.hotel_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopMetadataBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StopMetadataBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
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
          color: Theme.of(context).dividerColor.withValues(alpha: 0.78),
        ),
      ),
      child: child,
    );
  }
}
