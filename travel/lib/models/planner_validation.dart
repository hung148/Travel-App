enum PlannerValidationCode {
  duplicatePlace,
  dailyCostExceeded,
  dailyTimeExceeded,
  dailyPlaceCountExceeded,
  avoidableEmptyDay,
  unavoidableEmptyDay,
  totalActivityCostExceeded,
  dailyDiningLimitExceeded,
  avoidableFoodOnlyDay,
  unavoidableFoodOnlyDay,
}

enum PlannerValidationSeverity { warning, error }

class PlannerValidationIssue {
  final PlannerValidationCode code;
  final PlannerValidationSeverity severity;
  final String message;
  final int? dayNumber;

  const PlannerValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.dayNumber,
  });
}

class PlannerValidationResult {
  final List<PlannerValidationIssue> issues;

  const PlannerValidationResult({required this.issues});

  bool get isValid => issues.every(
    (issue) => issue.severity != PlannerValidationSeverity.error,
  );

  List<PlannerValidationIssue> get errors => issues
      .where((issue) => issue.severity == PlannerValidationSeverity.error)
      .toList();

  List<PlannerValidationIssue> get warnings => issues
      .where((issue) => issue.severity == PlannerValidationSeverity.warning)
      .toList();
}
