import '../models/budget_allocation.dart';
import '../models/spending_profile.dart';

class BudgetService {
  const BudgetService();

  BudgetAllocation allocateForTrip({
    required double totalBudget,
    double? accommodationCost,
  }) {
    if (!totalBudget.isFinite ||
        !(accommodationCost ?? 0).isFinite ||
        totalBudget < 0 ||
        (accommodationCost ?? 0) < 0 ||
        (accommodationCost ?? 0) > totalBudget) {
      throw ArgumentError('Hotel cost must fit inside the total trip budget.');
    }
    final hotel = accommodationCost ?? totalBudget * 0.38;
    final remaining = totalBudget - hotel;
    return BudgetAllocation(
      total: totalBudget,
      accommodation: hotel,
      food: remaining * 0.22 / 0.62,
      transportation: remaining * 0.14 / 0.62,
      activities: remaining * 0.21 / 0.62,
      buffer: remaining * 0.05 / 0.62,
    );
  }

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
