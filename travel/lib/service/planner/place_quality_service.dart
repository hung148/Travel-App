import '../../models/place_role.dart';
import '../../models/place_evidence.dart';

/// Defensive checks for noisy Maps records used by automatic recommendations.
class PlaceQualityService {
  const PlaceQualityService();

  static String normalize(String value) {
    var text = value.toLowerCase().replaceAll('đ', 'd');
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
    };
    for (final entry in groups.entries) {
      text = text.replaceAll(RegExp('[${entry.value}]'), entry.key);
    }
    return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  bool excluded({
    required String name,
    required Iterable<String> types,
    PlaceEvidence evidence = const PlaceEvidence.empty(),
  }) {
    // Product choice: malls are no longer automatic itinerary destinations.
    // Keep this at the common gate so every provider and direct planner input
    // follows the same rule, including mislabeled records with raw shop=mall.
    if (types.any((type) => type.toLowerCase().trim() == 'shopping_mall')) return true;
    if (evidenceExclusionReason(evidence) != null) return true;
    if (isNonItineraryPlace(types)) return true;
    return RegExp(
      r'\b(nghia trang|nghia dia|cemetery|graveyard|burial ground|ao ca|ho cau|cau ca|fishing pond|dntn|doanh nghiep tu nhan)\b',
    ).hasMatch(normalize(name));
  }

  /// Only clear negative evidence is used here. Missing reviews or metadata
  /// never imply rejection. These reasons also make decisions testable.
  String? evidenceExclusionReason(PlaceEvidence evidence) {
    final tags = evidence.osmTags.map(
      (key, value) => MapEntry(key, value.toLowerCase().trim()),
    );
    // A specific pedestrian permission overrides a general access restriction.
    // Conditional access needs date-aware evaluation in the scheduling step;
    // for now do not automatically visit a place with a restricted base rule.
    final foot = tags['foot'];
    const allowedFoot = {'yes', 'designated', 'permissive', 'customers'};
    final access =
        foot != null &&
            (allowedFoot.contains(foot) || {'no', 'private'}.contains(foot))
        ? foot
        : tags['access'];
    if (access == 'no' || access == 'private') {
      return 'Public access is prohibited or private.';
    }

    const lifecycles = {
      'disused',
      'abandoned',
      'demolished',
      'removed',
      'construction',
    };
    const functions = {'tourism', 'amenity', 'leisure', 'shop', 'historic'};
    bool present(String? value) =>
        value != null &&
        value.isNotEmpty &&
        !{'no', 'false', '0'}.contains(value);
    for (final status in lifecycles) {
      if (present(tags[status])) return 'Place is marked $status.';
      for (final function in functions) {
        final oldValue = tags['$status:$function'];
        if (!present(oldValue)) continue;
        final current = tags[function];
        // A former restaurant that is now a museum is not a closed museum.
        // Historical ruins are legitimate sights, not automatically abandoned.
        final hasCurrentFunction = functions.any((key) => present(tags[key]));
        if (oldValue == current || !hasCurrentFunction) {
          return 'Place function is marked $status.';
        }
      }
    }
    // Only an unconditional all-day closure is a rejection here. For example,
    // "Mo off; Tu-Su 09:00-17:00" must wait for date-aware scheduling.
    if ({
      'off',
      'closed',
      '24/7 off',
      '24/7 closed',
    }.contains(tags['opening_hours'])) {
      return 'Opening hours say the place is closed.';
    }

    // Raw OSM tags can expose an errand business even when the normalized
    // category says tourist_attraction. Keep food shops for the meal step.
    final amenity = tags['amenity'];
    if (isNonItineraryPlace([?amenity]) ||
        {
          'fuel',
          'charging_station',
          'doctors',
          'veterinary',
          'grave_yard',
        }.contains(amenity)) {
      return 'Place is a service or errand business, not a trip stop.';
    }
    final shop = tags['shop'];
    if (shop == 'mall') return 'Shopping malls are excluded from automatic plans.';
    if (present(shop) &&
        !{'mall', 'department_store', 'bakery'}.contains(shop)) {
      return 'Place is an individual retail shop, not a shopping destination.';
    }
    return null;
  }

  bool casualDining(String name, Iterable<String> types) {
    return RegExp(
          r'\b(quan nhau|bia hoi|beer garden|snack bar|fast food|street food)\b',
        ).hasMatch(normalize(name)) ||
        types.any(
          {
            'fast_food_restaurant',
            'snack_bar',
            'meal_takeaway',
            'pub',
            'sports_bar',
          }.contains,
        );
  }
}
