import 'dart:async';

import 'package:flutter/material.dart';
import 'package:travel/models/preference/preference_result.dart';

import '../models/feedback.dart' as model;
import '../models/hotel_selections.dart';
import '../models/itinerary.dart';
import '../models/planner_result.dart';
import '../models/preference/preferences.dart';
import '../models/trip/trip.dart';
import '../models/trip/trip_segment.dart';
import '../models/trip/travel_leg.dart';
import '../service/feedback_service.dart';
import '../service/itinerary_service.dart';
import '../service/preference_service.dart';
import '../service/trip_service.dart';

class TripViewModel extends ChangeNotifier {
  late final TripService _tripService;
  late final ItineraryService _itineraryService;
  late final PreferenceService _preferencesService;
  late final FeedbackService _feedbackService;

  TripViewModel({
    required TripService tripService,
    required ItineraryService itineraryService,
    required PreferenceService preferencesService,
    required FeedbackService feedbackService,
  }) {
    _tripService = tripService;
    _itineraryService = itineraryService;
    _preferencesService = preferencesService;
    _feedbackService = feedbackService;
  }

  /// Test-only constructor for Part 2 segment state tests.
  ///
  /// The segment methods do not use TripService, ItineraryService,
  /// PreferenceService, or FeedbackService, so tests can construct the
  /// ViewModel without Firebase/service dependencies.
  ///
  /// Do not call service-backed methods such as createTrip(), loadTripById(),
  /// generatePlan(), saveItinerary(), saveFeedback(), or deleteTrip() on an
  /// instance created with this constructor.
  TripViewModel.forSegmentTesting();

  // ---------------------------------------------------------------------------
  // EXISTING TRIP STATE
  // ---------------------------------------------------------------------------

  List<Trip> _tripHistory = [];
  List<Trip> get tripHistory => _tripHistory;

  Trip? _currentTrip;
  Trip? get currentTrip => _currentTrip;

  StreamSubscription<List<Trip>>? _tripSubscription;

  List<Itinerary> _itinerary = [];
  List<Itinerary> get itinerary => _itinerary;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  // ---------------------------------------------------------------------------
  // PART 2: MULTI-DESTINATION DRAFT STATE
  // ---------------------------------------------------------------------------

  final List<TripSegment> _draftSegments = [];
  final List<TravelLegDraft> _draftTravelLegs = [];

  /// Party size for the whole trip. Segment schedule costs are per person, so
  /// every total below has to scale by this.
  int _travelers = 1;
  String? _selectedSegmentId;

  List<TripSegment> get draftSegments => List.unmodifiable(_draftSegments);
  List<TravelLegDraft> get draftTravelLegs =>
      List.unmodifiable(_draftTravelLegs);

  int get travelers => _travelers;

  set travelers(int value) {
    final next = value < 1 ? 1 : value;
    if (next == _travelers) return;
    _travelers = next;
    notifyListeners();
  }

  void replaceTravelLegs(List<TravelLegDraft> legs) {
    _draftTravelLegs
      ..clear()
      ..addAll(legs);
    notifyListeners();
  }

  String? get selectedSegmentId => _selectedSegmentId;

  TripSegment? get selectedSegment {
    if (_selectedSegmentId == null) {
      return null;
    }

    return _findSegment(_selectedSegmentId!);
  }

  TripSegment? _findSegment(String segmentId) {
    for (final segment in _draftSegments) {
      if (segment.id == segmentId) {
        return segment;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // PART 3: COMBINED MULTI-DESTINATION TOTALS
  // ---------------------------------------------------------------------------

  double get totalHotelCost =>
      _draftSegments.fold(0, (total, segment) => total + segment.hotelCost);

  // Segment schedule costs are per person; the hotel is already a party
  // total. The ...For() methods on TripSegment handle that distinction.

  double get totalFoodCost => _draftSegments.fold(
    0,
    (total, segment) => total + segment.foodCostFor(_travelers),
  );

  double get totalActivityCost => _draftSegments.fold(
    0,
    (total, segment) => total + segment.activityCostFor(_travelers),
  );

  double get estimatedTripCost => _draftSegments.fold(
    0,
    (total, segment) => total + segment.estimatedTotalCostFor(_travelers),
  );

  int get totalTripDays =>
      _draftSegments.fold(0, (total, segment) => total + segment.numberOfDays);

  double segmentTotal(String segmentId) {
    return _findSegment(segmentId)?.estimatedTotalCostFor(_travelers) ?? 0;
  }

  void loadSegmentsFromTrip(Trip trip) {
    _draftSegments
      ..clear()
      ..addAll(trip.segments);

    _selectedSegmentId = _draftSegments.isEmpty
        ? null
        : _draftSegments.first.id;

    notifyListeners();
  }

  Future<void> saveDraftSegmentsToCurrentTrip({String? title}) async {
    final trip = _currentTrip;

    if (trip == null) {
      throw StateError(
        'No current trip is loaded. Create or load a trip before saving segments.',
      );
    }

    final updatedTrip = trip.copyWith(
      title: title,
      segments: List<TripSegment>.unmodifiable(_draftSegments),
    );

    await editTrip(updatedTrip);
  }

  void _replaceSegment(String segmentId, TripSegment updatedSegment) {
    final index = _draftSegments.indexWhere(
      (segment) => segment.id == segmentId,
    );

    if (index == -1) {
      return;
    }

    _draftSegments[index] = updatedSegment;
    notifyListeners();
  }

  void addSegment(TripSegment segment) {
    final alreadyExists = _draftSegments.any(
      (existing) => existing.id == segment.id,
    );

    if (alreadyExists) {
      return;
    }

    _draftSegments.add(segment);
    _selectedSegmentId = segment.id;
    notifyListeners();
  }

  void selectSegment(String segmentId) {
    final exists = _draftSegments.any((segment) => segment.id == segmentId);

    if (!exists || _selectedSegmentId == segmentId) {
      return;
    }

    _selectedSegmentId = segmentId;
    notifyListeners();
  }

  void updateSegment(String segmentId, TripSegment updatedSegment) {
    if (segmentId != updatedSegment.id) {
      throw ArgumentError('Segment ID must match updated segment ID.');
    }

    _replaceSegment(segmentId, updatedSegment);
  }

  void updateSegmentHotel(String segmentId, HotelSelection? hotel) {
    final segment = _findSegment(segmentId);

    if (segment == null) {
      return;
    }

    // NOTE:
    // If your TripSegment.copyWith uses "hotel: hotel ?? this.hotel",
    // passing null will NOT remove an existing hotel. That is okay for Part 2.
    final updated = segment.copyWith(hotel: hotel);
    _replaceSegment(segmentId, updated);
  }

  void updateSegmentPlan(String segmentId, List<PlannerDay> days) {
    final segment = _findSegment(segmentId);

    if (segment == null) {
      return;
    }

    final updated = segment.copyWith(
      days: List<PlannerDay>.unmodifiable(days),
    );

    _replaceSegment(segmentId, updated);
  }

  void applyPlannerResultToSegment(
    String segmentId,
    PlannerResult plannerResult,
  ) {
    updateSegmentPlan(segmentId, plannerResult.days);
  }

  void removeSegment(String segmentId) {
    final index = _draftSegments.indexWhere(
      (segment) => segment.id == segmentId,
    );

    if (index == -1) {
      return;
    }

    final wasSelected = _selectedSegmentId == segmentId;
    _draftSegments.removeAt(index);
    _draftTravelLegs.removeWhere(
      (leg) =>
          leg.fromDestinationId == segmentId ||
          leg.toDestinationId == segmentId,
    );

    if (wasSelected) {
      if (_draftSegments.isEmpty) {
        _selectedSegmentId = null;
      } else {
        final nextIndex = index < _draftSegments.length
            ? index
            : _draftSegments.length - 1;
        _selectedSegmentId = _draftSegments[nextIndex].id;
      }
    }

    notifyListeners();
  }

  void clearDraftTrip() {
    _draftSegments.clear();
    _draftTravelLegs.clear();
    _selectedSegmentId = null;
    notifyListeners();
  }

  /// Creates the temporary single-destination Trip that your EXISTING
  /// TravelPlannerService already expects.
  ///
  /// This means TravelPlannerService does NOT need to understand the entire
  /// multi-destination trip yet. Generate one segment, then call
  /// applyPlannerResultToSegment(segment.id, result).
  Trip buildPlannerTripForSegment({
    required String segmentId,
    required String ownerId,
  }) {
    final segment = _findSegment(segmentId);

    if (segment == null) {
      throw StateError('Trip segment $segmentId was not found.');
    }

    return Trip(
      id: 'segment_${segment.id}',
      ownerId: ownerId,
      destination: segment.destination,
      budget: segment.allocatedBudget,
      days: segment.numberOfDays,
      status: 'draft',
      startDate: segment.startDate,
      endDate: segment.endDate,
    );
  }

  // ---------------------------------------------------------------------------
  // EXISTING VIEWMODEL METHODS
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }

  void _startOperation() {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _setSuccess(String? message) {
    _successMessage = message;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> createTrip(Trip trip) async {
    _startOperation();

    final result = await _tripService.addTrip(trip);

    if (result.success) {
      _currentTrip = trip;
      _draftSegments
        ..clear()
        ..addAll(trip.segments);
      _selectedSegmentId = _draftSegments.isEmpty
          ? null
          : _draftSegments.first.id;
      _successMessage = 'Trip created successfully.';
    } else {
      _errorMessage = 'Unable to create your trip. Please try again.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> editTrip(Trip updatedTrip) async {
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      await _tripService.updateTrip(updatedTrip);

      final index = _tripHistory.indexWhere(
        (trip) => trip.id == updatedTrip.id,
      );
      if (index != -1) {
        _tripHistory[index] = updatedTrip;
      }

      if (_currentTrip?.id == updatedTrip.id) {
        _currentTrip = updatedTrip;
      }

      _setSuccess('Trip updated successfully.');
      notifyListeners();
    } catch (e) {
      _setError('Failed to update trip: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> listenToTripHistory(String ownerId) async {
    _startOperation();
    await _tripSubscription?.cancel();

    _tripSubscription = _tripService
        .getTripsByUser(ownerId)
        .listen(
          (trips) {
            _tripHistory = trips;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = 'Unable to load your trips. Please try again.';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> loadTripById(String tripId) async {
    try {
      _setLoading(true);
      _setError(null);

      final result = await _tripService.getTripById(tripId);
      if (result.success) {
        _currentTrip = result.data;

        _draftSegments.clear();
        if (_currentTrip != null) {
          _draftSegments.addAll(_currentTrip!.segments);
        }
        _selectedSegmentId = _draftSegments.isEmpty
            ? null
            : _draftSegments.first.id;

        _itinerary = await _itineraryService.getItinerary(tripId);
        notifyListeners();
      } else {
        _setError(result.error ?? 'Unknown error');
      }
    } catch (e) {
      _setError('Failed to load trip: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> generatePlan({
    required Trip trip,
    required String ownerId,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      final PreferenceResult result = await _preferencesService.getPreferences(
        ownerId,
      );

      if (!result.success || result.data == null) {
        _setError(
          (result.error ?? '').isEmpty
              ? 'Failed to load preference'
              : result.error,
        );
        return;
      }

      final Preference preference = result.data!;
      final List<Itinerary> generated = [];

      for (int i = 1; i <= trip.days; i++) {
        generated.add(
          Itinerary(
            id: '${trip.id}_day_$i',
            tripId: trip.id,
            dayNumber: i,
            // Interpolating the raw list printed Dart's "[Nature, Coffee]"
            // brackets, and interests holds the same tags as experienceType,
            // so the old meals line just repeated them.
            places: preference.styleTags.isEmpty
                ? 'Places in ${trip.destination}'
                : '${preference.styleTags.join(', ')} places in '
                      '${trip.destination}',
            meals: preference.spendingStyle.trim().isEmpty
                ? 'Meal plan'
                : '${preference.spendingStyle} meal plan',
            estimatedCost: trip.budget / trip.days,
          ),
        );
      }

      _itinerary = generated;
      _setSuccess('Plan generated successfully.');
      notifyListeners();
    } catch (e) {
      _setError('Failed to generate plan: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveItinerary(String tripId) async {
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      final items = _itinerary.where((item) => item.tripId == tripId).toList();
      if (items.isEmpty) {
        throw StateError('No itinerary exists for this trip.');
      }
      await _itineraryService.saveItinerary(items);

      _setSuccess('Itinerary saved successfully.');
    } catch (e) {
      _setError('Failed to save itinerary: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveFeedback({required model.Feedback feedback}) async {
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      await _feedbackService.saveFeedback(feedback: feedback);

      _setSuccess('Feedback saved successfully.');
    } catch (e) {
      _setError('Failed to save feedback: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      final result = await _tripService.deleteTrip(tripId);

      if (!result.success) {
        _setError(result.error ?? 'Fail to delete trip');
        return;
      }

      _tripHistory.removeWhere((trip) => trip.id == tripId);

      if (_currentTrip?.id == tripId) {
        _currentTrip = null;
        _itinerary = [];
      }

      _setSuccess('Trip deleted successfully.');
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete trip: $e');
    } finally {
      _setLoading(false);
    }
  }

  void setCurrentTrip(Trip trip) {
    _currentTrip = trip;
    notifyListeners();
  }

  void clearCurrentTrip() {
    _currentTrip = null;
    _itinerary = [];
    notifyListeners();
  }
}
