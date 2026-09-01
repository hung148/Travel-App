import '../models/budget_allocation.dart';

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

    final percentages = _percentagesFor(spendingStyle);

    return BudgetAllocation(
      total: totalBudget,
      accommodation: totalBudget * percentages.accommodation,
      food: totalBudget * percentages.food,
      transportation: totalBudget * percentages.transportation,
      activities: totalBudget * percentages.activities,
      buffer: totalBudget * percentages.buffer,
    );
  }

  _BudgetPercentages _percentagesFor(String spendingStyle) {
    return switch (spendingStyle.toLowerCase().trim()) {
      'budget' => const _BudgetPercentages(
        accommodation: 0.35,
        food: 0.22,
        transportation: 0.15,
        activities: 0.18,
        buffer: 0.10,
      ),
      'luxury' => const _BudgetPercentages(
        accommodation: 0.40,
        food: 0.20,
        transportation: 0.10,
        activities: 0.25,
        buffer: 0.05,
      ),
      _ => const _BudgetPercentages(
        accommodation: 0.40,
        food: 0.20,
        transportation: 0.15,
        activities: 0.20,
        buffer: 0.05,
      ),
    };
  }
}

class _BudgetPercentages {
  final double accommodation;
  final double food;
  final double transportation;
  final double activities;
  final double buffer;

  const _BudgetPercentages({
    required this.accommodation,
    required this.food,
    required this.transportation,
    required this.activities,
    required this.buffer,
  });
}
