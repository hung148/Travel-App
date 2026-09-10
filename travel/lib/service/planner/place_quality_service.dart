import '../../models/place_role.dart';

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

  bool excluded({required String name, required Iterable<String> types}) {
    if (isNonItineraryPlace(types)) return true;
    return RegExp(
      r'\b(nghia trang|nghia dia|cemetery|graveyard|burial ground|ao ca|ho cau|cau ca|fishing pond|dntn|doanh nghiep tu nhan)\b',
    ).hasMatch(normalize(name));
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
