import 'dart:math';
import '../../models/score_place.dart';

/// Selects complete days against the per-person food allowance.
/// Legacy spending strings have no effect on recommendations.
class DiningSelectionService {
  const DiningSelectionService();

  List<List<ScoredPlace>> select({
    required List<ScoredPlace> candidates,
    required int days,
    required int mealsPerDay,
    required double dailyBudget,
    String spendingStyle = 'Normal',
  }) {
    final used = <String, int>{};
    final cheap = [...candidates]
      ..sort((a, b) => a.place.estimatedCost.compareTo(b.place.estimatedCost));
    final result = <List<ScoredPlace>>[];
    for (var dayIndex = 0; dayIndex < days; dayIndex++) {
      final day = <ScoredPlace>[];
      final selectedIds = <String>{};
      var remaining = dailyBudget;
      // Reserve dinner first, then breakfast and lunch; output stays chronological.
      for (var slot = 0; slot < mealsPerDay; slot++) {
        ScoredPlace? best;
        var bestScore = -double.infinity;
        final target =
            dailyBudget *
            (slot == 0
                ? 0.5
                : slot == 1
                ? 0.2
                : 0.3);
        for (final candidate in candidates) {
          if (selectedIds.contains(candidate.place.id)) continue;
          var reserved = 0.0;
          var reservedCount = 0;
          for (final other in cheap) {
            if (reservedCount == mealsPerDay - slot - 1) break;
            if (selectedIds.contains(other.place.id) ||
                other.place.id == candidate.place.id) {
              continue;
            }
            reserved += other.place.estimatedCost;
            reservedCount++;
          }
          if (reservedCount != mealsPerDay - slot - 1 ||
              candidate.place.estimatedCost + reserved > remaining + 0.001) {
            continue;
          }
          final fit = target <= 0
              ? 1.0
              : (1 - (candidate.place.estimatedCost - target).abs() / target)
                    .clamp(0.0, 1.0);
          final confidence = candidate.place.cost.source.name == 'unknown'
              ? -25.0
              : 0.0;
          // Prefer a well-reviewed premium dining match for dinner when its
          // price fits. This is evidence from discovery, never a user category.
          final premiumDinner =
              slot == 0 &&
                  candidate.place.rating >= 4 &&
                  (candidate.place.cost.priceLevel ?? 0) >= 3 &&
                  (candidate.place.luxuryDiningSearchMatch ||
                      candidate.place.category == 'fine_dining_restaurant')
              ? 8.0
              : 0.0;
          final score =
              candidate.totalScore * 0.45 +
              fit * 50 +
              confidence +
              premiumDinner -
              min(used[candidate.place.id] ?? 0, 5) * 2;
          if (score > bestScore) {
            best = candidate;
            bestScore = score;
          }
        }
        if (best == null) {
          throw StateError(
            'The daily allowance cannot cover the required meals.',
          );
        }
        day.add(best);
        selectedIds.add(best.place.id);
        used.update(best.place.id, (value) => value + 1, ifAbsent: () => 1);
        remaining -= best.place.estimatedCost;
      }
      day.add(day.removeAt(0));
      result.add(day);
    }
    return result;
  }
}
