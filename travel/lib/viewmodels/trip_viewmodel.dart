import 'dart:async';

import 'package:flutter/material.dart';
import 'package:travel/models/preference/preference_result.dart';

import '../models/trip/trip.dart';
import '../models/itinerary.dart';
import '../models/feedback.dart' as model;
import '../models/preference/preferences.dart';
import '../service/trip_service.dart';
import '../service/itinerary_service.dart';
import '../service/preference_service.dart';
import '../service/feedback_service.dart';

class TripViewModel extends ChangeNotifier {
  final TripService _tripService;
  final ItineraryService _itineraryService;
  final PreferenceService _preferencesService;
  final FeedbackService _feedbackService;

  TripViewModel({
    required TripService tripService,
    required ItineraryService itineraryService,
    required PreferenceService preferencesService,
    required FeedbackService feedbackService,
  }) : _tripService = tripService,
       _itineraryService = itineraryService,
       _preferencesService = preferencesService,
       _feedbackService = feedbackService;

  List<Trip> _tripHistory = [];
  List<Trip> get tripHistory => _tripHistory;

  Trip? _currentTrip;
  Trip? get currentTrip => _currentTrip;

  // A SstreamSubscription is simply the object that represents your connection to a Stream
  StreamSubscription<List<Trip>>? _tripSubscription;

  List<Itinerary> _itinerary = [];
  List<Itinerary> get itinerary => _itinerary;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  @override
  void dispose() {
    // if you don't cancel the subscription, the Stream keeps sending updates.
    // Even after the screen is closed
    // This might lead to memory leaks
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

  // Change loadTripHistory to listenToTripHistory because
  // getTripByUser return a stream which is automatically update
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
          (result.error ?? "").isEmpty
              ? "Failed to load preference"
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
            places:
                '${preference.experienceType} places in ${trip.destination}',
            meals: '${preference.interests.join(", ")} meal plan',
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
