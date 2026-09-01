import 'planner_result.dart';

class PlanRefinementResult {
  final PlannerResult plan;
  final String message;
  final bool changed;

  const PlanRefinementResult({
    required this.plan,
    required this.message,
    required this.changed,
  });
}
