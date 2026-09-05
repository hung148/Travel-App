import '../models/budget_allocation.dart';
import '../models/spending_profile.dart';

class BudgetService {
  const BudgetService();

  BudgetAllocation allocate({
    required double totalBudget,
    required String spendingStyle,
  }) {
    if (totalBudget < 0) {
      throw ArgumentError.value(
        totalBudget,
        'totalBudget',
        'Cannot be negative',
      );
    }

    // The split and the ranking are driven by the same profile, so a style
    // cannot allocate like Luxury while ranking like Budget.
    final profile = SpendingProfile.fromName(spendingStyle);

    return BudgetAllocation(
      total: totalBudget,
      accommodation: totalBudget * profile.accommodationShare,
      food: totalBudget * profile.foodShare,
      transportation: totalBudget * profile.transportationShare,
      activities: totalBudget * profile.activitiesShare,
      buffer: totalBudget * profile.bufferShare,
    );
  }

  BudgetAllocation? ensureMinimumFoodBudget({
    required BudgetAllocation allocation,
    required double minimumFoodBudget,
  }) {
    if (minimumFoodBudget <= allocation.food) return allocation;

    final additionalFood = minimumFoodBudget - allocation.food;
    if (additionalFood > allocation.buffer + 0.001) return null;

    return BudgetAllocation(
      total: allocation.total,
      accommodation: allocation.accommodation,
      food: minimumFoodBudget,
      transportation: allocation.transportation,
      activities: allocation.activities,
      buffer: allocation.buffer - additionalFood,
    );
  }

}

