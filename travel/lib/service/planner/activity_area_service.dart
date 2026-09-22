import 'dart:math';

import '../../models/travel_place.dart';
import '../../models/planner_profile.dart';

/// A small-area approximation, not administrative neighborhood boundaries.
/// Used for activity variety; meals can remain conveniently close to sights.
class ActivityAreaService {
  const ActivityAreaService();

  static const neighborhoodKm = 1.0;

  double distanceKm(TravelPlace a, TravelPlace b) {
    const radians = pi / 180;
    final lat = (b.latitude - a.latitude) * radians;
    final lon = (b.longitude - a.longitude) * radians;
    final h =
        pow(sin(lat / 2), 2) +
        cos(a.latitude * radians) *
            cos(b.latitude * radians) *
            pow(sin(lon / 2), 2);
    return 6371 * 2 * asin(sqrt(h.clamp(0.0, 1.0)));
  }

  int areaCount(Iterable<TravelPlace> places) {
    final representatives = <TravelPlace>[];
    for (final place in places.where((p) => p.hasLocation && !p.isDining)) {
      if (representatives.every(
        (other) => distanceKm(place, other) >= neighborhoodKm,
      )) {
        representatives.add(place);
      }
    }
    return representatives.length;
  }

  /// A bounded preference for variety, never a ban on nearby good sights.
  /// Do not reward arbitrary distance: 2km and 20km give the same zero penalty.
  double repetitionPenalty(
    TravelPlace place,
    Iterable<TravelPlace> selected, {
    required PlannerProfile profile,
  }) {
    if (!place.hasLocation || profile.style == PlannerStyle.relaxed) return 0;
    final explorer = profile.style == PlannerStyle.explorer;
    final nearby = selected
        .where(
          (other) =>
              other.hasLocation &&
              !other.isDining &&
              distanceKm(place, other) < (explorer ? 2.0 : neighborhoodKm),
        )
        .length;
    return min(explorer ? 30.0 : 20.0, nearby * (explorer ? 18.0 : 12.0));
  }
}
