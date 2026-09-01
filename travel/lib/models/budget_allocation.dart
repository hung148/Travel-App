class BudgetAllocation {
  final double total;
  final double accommodation;
  final double food;
  final double transportation;
  final double activities;
  final double buffer;

  const BudgetAllocation({
    required this.total,
    required this.accommodation,
    required this.food,
    required this.transportation,
    required this.activities,
    required this.buffer,
  });

  double get allocatedTotal =>
      accommodation + food + transportation + activities + buffer;

  double dailyActivitiesBudget(int days) {
    if (days <= 0) throw ArgumentError.value(days, 'days', 'Must be positive');
    return activities / days;
  }
}
