import 'package:flutter/material.dart';

import '../models/trip/trip.dart';
import '../models/itinerary.dart';
import '../models/feedback.dart';
import '../models/preferences.dart';
import '../services//trip_service.dart';
import '../services/itinerary_service.dart';
import '../services/preferences_service.dart';

class TripViewModel extends ChangeNotifier {
  final TripService _tripService;
  final ItineraryService _itineraryService;
  final PreferencesService _preferencesService;

  TripViewModel({
    required TripService tripService,
    required ItineraryService itineraryService,
    required PreferencesService preferencesService,
  })  : _tripService = tripService,
        _itineraryService = itineraryService,
        _preferencesService = preferencesService;

  List<Trip> _tripHistory = [];
  List<Trip> get tripHistory => _tripHistory;

  Trip? _currentTrip;
  Trip? get currentTrip => _currentTrip;

  List<Itinerary> _itinerary = [];
  List<Itinerary> get itinerary => _itinerary;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

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
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      await _tripService.saveTrip(trip);

      _tripHistory.insert(0, trip);
      _currentTrip = trip;

      _setSuccess('Trip created successfully.');
    } catch (e) {
      _setError('Failed to create trip: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> editTrip(Trip updatedTrip) async {
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      await _tripService.updateTrip(updatedTrip);

      final index = _tripHistory.indexWhere((trip) => trip.id == updatedTrip.id);
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

  Future<void> loadTripHistory(String ownerId) async {
    try {
      _setLoading(true);
      _setError(null);

      _tripHistory = await _tripService.getTripsByOwner(ownerId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load trip history: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTripById(String tripId) async {
    try {
      _setLoading(true);
      _setError(null);

      _currentTrip = await _tripService.getTripById(tripId);
      _itinerary = await _itineraryService.getItinerary(tripId);

      notifyListeners();
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

      final Preference preference =
          await _preferencesService.getPreferences(ownerId);

      final List<Itinerary> generated = [];

      for (int i = 1; i <= trip.days; i++) {
        generated.add(
          Itinerary(
            id: '$i',
            dayNumber: i,
            places: '${preference.experienceType} places in ${trip.destination}',
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

      await _itineraryService.saveItinerary(
        tripId: tripId,
        itinerary: _itinerary,
      );

      _setSuccess('Itinerary saved successfully.');
    } catch (e) {
      _setError('Failed to save itinerary: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveFeedback({
    required String tripId,
    required FeedbackModel feedback,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      _setSuccess(null);

      await _itineraryService.saveFeedback(
        tripId: tripId,
        feedback: feedback,
      );

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

      await _tripService.deleteTrip(tripId);

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