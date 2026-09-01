import 'budget_allocation.dart';
import 'planner_profile.dart';
import 'planner_validation.dart';
import 'score_place.dart';

class PlannerDay {
  final int dayNumber;
  final List<ScoredPlace> places;

  const PlannerDay({required this.dayNumber, required this.places});

  double get estimatedCost {
    return places.fold(0, (total, item) => total + item.place.estimatedCost);
  }

  int get estimatedVisitMinutes {
    return places.fold(
      0,
      (total, item) => total + item.place.estimatedVisitMinutes,
    );
  }
}

class PlannerResult {
  final BudgetAllocation budgetAllocation;
  final PlannerValidationResult validation;
  final PlannerProfile profile;
  final List<ScoredPlace> rankedPlaces;
  final List<PlannerDay> days;

  const PlannerResult({
    required this.budgetAllocation,
    required this.validation,
    required this.profile,
    required this.rankedPlaces,
    required this.days,
  });

  double get totalEstimatedCost {
    return days.fold(0, (total, day) => total + day.estimatedCost);
  }
}
