enum SpendingStyle { budget, normal, luxury }

/// Everything the user's spending style changes, in one place.
///
/// It used to change only the budget split, and by so little that Budget,
/// Normal and Luxury produced the same itinerary: the scorer never saw the
/// style at all, and its cost rule was "cheaper is always better", so a luxury
/// traveler got the same cheap-first ranking as everyone else.
///
/// Now the style says which price band a stop should land in, how hard to
/// push back when a place misses that band, and how the money is split.
class SpendingProfile {
  final SpendingStyle style;
  final String label;

  // --- Budget split. Each set sums to 1.0. ---
  final double accommodationShare;
  final double foodShare;
  final double transportationShare;
  final double activitiesShare;
  final double bufferShare;

  /// The share of a day's allowance a single stop should ideally cost.
  ///
  /// This is the heart of it: Budget wants stops well under the daily figure,
  /// Luxury wants most of the day's allowance going into fewer, better places.
  final double targetCostRatio;

  /// How much to penalise a stop that costs LESS than the target.
  ///
  /// Zero for Budget - cheaper is never a complaint. High for Luxury, where a
  /// bargain stop is a miss, which is what makes the styles diverge instead of
  /// all converging on the cheapest candidates.
  final double underspendPenalty;

  /// How much to penalise a stop that costs MORE than the target.
  final double overspendPenalty;

  /// Applied to the planner profile's own weights, then renormalised, so
  /// spending style shifts what the ranking cares about without discarding
  /// the pace profile's balance.
  final double ratingWeightFactor;
  final double budgetWeightFactor;

  const SpendingProfile({
    required this.style,
    required this.label,
    required this.accommodationShare,
    required this.foodShare,
    required this.transportationShare,
    required this.activitiesShare,
    required this.bufferShare,
    required this.targetCostRatio,
    required this.underspendPenalty,
    required this.overspendPenalty,
    required this.ratingWeightFactor,
    required this.budgetWeightFactor,
  });

  /// Cheap stops, a big safety buffer, and cost matters more than anything.
  static const budget = SpendingProfile(
    style: SpendingStyle.budget,
    label: 'Budget',
    accommodationShare: 0.32,
    foodShare: 0.24,
    transportationShare: 0.16,
    activitiesShare: 0.16,
    bufferShare: 0.12,
    targetCostRatio: 0.15,
    underspendPenalty: 0.0,
    overspendPenalty: 1.0,
    ratingWeightFactor: 0.85,
    budgetWeightFactor: 2.2,
  );

  static const normal = SpendingProfile(
    style: SpendingStyle.normal,
    label: 'Normal',
    accommodationShare: 0.38,
    foodShare: 0.22,
    transportationShare: 0.14,
    activitiesShare: 0.21,
    bufferShare: 0.05,
    targetCostRatio: 0.32,
    underspendPenalty: 0.35,
    overspendPenalty: 0.75,
    ratingWeightFactor: 1.0,
    budgetWeightFactor: 1.0,
  );

  /// Fewer, better places. A cheap stop is a miss, and rating carries more
  /// weight than it does for the other styles.
  ///
  /// The buffer stays at 5% rather than going to zero: `ensureMinimumFoodBudget`
  /// borrows from it to guarantee three meals a day, and a trip that cannot
  /// cover them is rejected outright.
  static const luxury = SpendingProfile(
    style: SpendingStyle.luxury,
    label: 'Luxury',
    accommodationShare: 0.41,
    foodShare: 0.21,
    transportationShare: 0.11,
    activitiesShare: 0.22,
    bufferShare: 0.05,
    targetCostRatio: 0.60,
    underspendPenalty: 0.85,
    overspendPenalty: 0.45,
    ratingWeightFactor: 1.5,
    budgetWeightFactor: 1.6,
  );

  static const values = [budget, normal, luxury];

  /// Unknown or empty styles fall to Normal rather than failing - the value
  /// comes from a Firestore string.
  factory SpendingProfile.fromName(String? value) {
    return switch ((value ?? '').toLowerCase().trim()) {
      'budget' || 'cheap' || 'thrifty' => budget,
      'luxury' || 'premium' || 'high-end' => luxury,
      _ => normal,
    };
  }

  /// How well a stop's cost fits this style, 0-100.
  ///
  /// Asymmetric on purpose. Anything that eats a whole day's allowance scores
  /// near zero whatever the style, but below the target the three styles
  /// disagree sharply: Budget is delighted, Luxury is not.
  double costFitScore({
    required double placeCost,
    required double dailyBudget,
  }) {
    if (dailyBudget <= 0) return 50;

    final ratio = placeCost / dailyBudget;
    if (!ratio.isFinite) return 50;

    // One stop consuming the entire day's allowance is a bad pick for anyone.
    if (ratio > 1) return 8;

    if (ratio <= targetCostRatio) {
      if (targetCostRatio <= 0) return 100;
      final shortfall = (targetCostRatio - ratio) / targetCostRatio;
      return (100 - 100 * shortfall * underspendPenalty).clamp(8, 100);
    }

    final headroom = 1 - targetCostRatio;
    final overshoot = headroom <= 0 ? 1.0 : (ratio - targetCostRatio) / headroom;
    return (100 - 100 * overshoot * overspendPenalty).clamp(8, 100);
  }
}
