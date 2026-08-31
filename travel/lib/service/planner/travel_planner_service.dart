import '../../models/planner_result.dart';
import '../../models/preference/preferences.dart';
import '../../models/travel_place.dart';
import '../../models/trip/trip.dart';
import 'place_scoring_service.dart';

class TravelPlannerService {
  final PlaceScoringService placeScoringService;

  TravelPlannerService({
    required this.placeScoringService,
  });

  PlannerResult generatePlan({
    required Trip trip,
    required Preference preference,
    required List<TravelPlace> candidatePlaces,
    required double centerLatitude,
    required double centerLongitude,
  }) {
    if (trip.days <= 0) {
      throw ArgumentError('Trip must have at least one day.');
    }

    if (candidatePlaces.isEmpty) {
      return const PlannerResult(
        rankedPlaces: [],
        days: [],
      );
    }

    final activityBudget =
        _calculateActivityBudget(
      trip: trip,
      preference: preference,
    );

    final dailyActivityBudget =
        activityBudget / trip.days;

    final rankedPlaces =
        placeScoringService.rankPlaces(
      places: candidatePlaces,
      preference: preference,
      dailyActivityBudget: dailyActivityBudget,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );

    final maxPerDay =
        _activitiesPerDay(preference.activityLevel);

    final maxPlaces =
        trip.days * maxPerDay;

    final selectedPlaces =
        rankedPlaces.take(maxPlaces).toList();

    final days = List.generate(
      trip.days,
      (index) => PlannerDay(
        dayNumber: index + 1,
        places: [],
      ),
    );

    _distributePlaces(
      selectedPlaces: selectedPlaces,
      days: days,
      maxPerDay: maxPerDay,
      dailyActivityBudget: dailyActivityBudget,
    );

    return PlannerResult(
      rankedPlaces: rankedPlaces,
      days: days,
    );
  }

  double _calculateActivityBudget({
    required Trip trip,
    required Preference preference,
  }) {
    double activityPercentage;

    switch (preference.spendingStyle.toLowerCase()) {
      case 'budget':
        activityPercentage = 0.18;
        break;

      case 'luxury':
        activityPercentage = 0.25;
        break;

      default:
        activityPercentage = 0.20;
    }

    final interests = preference.interests
        .map((e) => e.toLowerCase())
        .toList();

    final experienceTypes = preference.experienceType
        .map((e) => e.toLowerCase())
        .toList();

    if (interests.contains('attractions') ||
        interests.contains('museums') ||
        experienceTypes.contains('adventure')) {
      activityPercentage += 0.05;
    }

    return trip.budget * activityPercentage;
  }

  int _activitiesPerDay(String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'relaxed':
        return 3;

      case 'very active':
        return 6;

      default:
        return 4;
    }
  }

  void _distributePlaces({
    required List selectedPlaces,
    required List<PlannerDay> days,
    required int maxPerDay,
    required double dailyActivityBudget,
  }) {
    final dayCosts = List<double>.filled(
      days.length,
      0,
    );

    int dayIndex = 0;

    for (final scoredPlace in selectedPlaces) {
      int attempts = 0;

      while (attempts < days.length) {
        final day = days[dayIndex];

        final hasSpace =
            day.places.length < maxPerDay;

        final projectedCost =
            dayCosts[dayIndex] +
            scoredPlace.place.estimatedCost;

        final withinBudget =
            projectedCost <= dailyActivityBudget;

        if (hasSpace && withinBudget) {
          day.places.add(scoredPlace);
          dayCosts[dayIndex] =
              projectedCost;

          dayIndex =
              (dayIndex + 1) % days.length;

          break;
        }

        dayIndex =
            (dayIndex + 1) % days.length;

        attempts++;
      }
    }
  }
}