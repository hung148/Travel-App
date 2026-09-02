import 'budget_allocation.dart';
import 'planner_profile.dart';
import 'planner_validation.dart';
import 'score_place.dart';
import 'hotel_stay.dart';

class PlannerDay {
  final int dayNumber;
  final List<ScoredPlace> places;

  const PlannerDay({required this.dayNumber, required this.places});

  double get estimatedCost {
    return places.fold(0, (total, item) => total + item.place.estimatedCost);
  }

  double get estimatedFoodCost => places
      .where((item) => item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedCost);

  double get estimatedActivityCost => places
      .where((item) => !item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedCost);

  int get estimatedVisitMinutes {
    return places.fold(
      0,
      (total, item) => total + item.place.estimatedVisitMinutes,
    );
  }

  int get estimatedActivityMinutes => places
      .where((item) => !item.place.isDining)
      .fold(0, (total, item) => total + item.place.estimatedVisitMinutes);

  int get diningCount => places.where((item) => item.place.isDining).length;

  int get activityCount => places.where((item) => !item.place.isDining).length;

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'places': places.map((item) => item.toMap()).toList(),
    };
  }

  factory PlannerDay.fromMap(Map<String, dynamic> data) {
    final placeList = data['places'] as List<dynamic>? ?? const [];

    return PlannerDay(
      dayNumber: (data['dayNumber'] as num?)?.toInt() ?? 0,
      places: placeList
          .whereType<Map>()
          .map(
            (item) => ScoredPlace.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class PlannerResult {
  final BudgetAllocation budgetAllocation;
  final PlannerValidationResult validation;
  final PlannerProfile profile;
  final List<ScoredPlace> rankedPlaces;
  final List<PlannerDay> days;
  final HotelStay? hotel;

  const PlannerResult({
    required this.budgetAllocation,
    required this.validation,
    required this.profile,
    required this.rankedPlaces,
    required this.days,
    this.hotel,
  });

  double get totalEstimatedCost {
    return days.fold(0, (total, day) => total + day.estimatedCost);
  }

  double get totalEstimatedFoodCost =>
      days.fold(0, (total, day) => total + day.estimatedFoodCost);

  double get totalEstimatedActivityCost =>
      days.fold(0, (total, day) => total + day.estimatedActivityCost);

  double get totalEstimatedTripCost =>
      totalEstimatedCost + (hotel?.totalCost ?? 0);
}
