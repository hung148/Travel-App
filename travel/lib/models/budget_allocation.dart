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

  // --- Group units -------------------------------------------------------
  // Everything above, and the two accessors here, is money for the WHOLE
  // party. That is what the user typed into the budget field.

  double dailyActivitiesBudget(int days) {
    if (days <= 0) throw ArgumentError.value(days, 'days', 'Must be positive');
    return activities / days;
  }

  double dailyFoodBudget(int days) {
    if (days <= 0) throw ArgumentError.value(days, 'days', 'Must be positive');
    return food / days;
  }

  // --- Per-person units --------------------------------------------------
  // The planner scores and packs places whose costs are per person, so it must
  // compare against these rather than the group slices above. Accommodation
  // deliberately has no per-person form: hotels are priced per room.

  double dailyActivitiesBudgetPerPerson(int days, int travelers) =>
      dailyActivitiesBudget(days) / _party(travelers);

  double dailyFoodBudgetPerPerson(int days, int travelers) =>
      dailyFoodBudget(days) / _party(travelers);

  double foodPerPerson(int travelers) => food / _party(travelers);

  double activitiesPerPerson(int travelers) => activities / _party(travelers);

  static int _party(int travelers) => travelers < 1 ? 1 : travelers;
}
