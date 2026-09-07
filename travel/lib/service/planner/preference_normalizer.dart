class PreferenceNormalizer {
  const PreferenceNormalizer();

  /// A shopping preference means malls and large markets. Shops - specialty
  /// or otherwise - never reach scoring, so they are deliberately absent.
  static const Set<String> _shopping = {
    'shopping',
    'shopping_mall',
    'market',
    'mall',
  };

  static const Map<String, Set<String>> _synonyms = {
    'food': {'food', 'local_food', 'restaurant', 'cafe', 'dining'},
    'local_food': {'food', 'local_food', 'restaurant', 'cafe', 'dining'},
    'restaurant': {'food', 'local_food', 'restaurant', 'cafe', 'dining'},
    'dining': {'food', 'local_food', 'restaurant', 'cafe', 'dining'},
    'coffee': {'coffee', 'cafe', 'food', 'dining'},
    'cafe': {'coffee', 'cafe', 'food', 'dining'},
    'museums': {'museums', 'museum', 'art_gallery'},
    'museum': {'museums', 'museum', 'art_gallery'},
    'art_gallery': {'museums', 'museum', 'art_gallery'},
    'nature': {'nature', 'park', 'beach', 'garden'},
    'park': {'nature', 'park', 'beach', 'garden'},
    'beach': {'beach', 'nature', 'park'},
    'culture': {'culture', 'museum', 'art_gallery', 'history'},
    'sightseeing': {
      'sightseeing',
      'tourist_attraction',
      'landmark',
      'monument',
    },
    'entertainment': {
      'entertainment',
      'amusement_park',
      'bowling_alley',
      'nightlife',
    },
    'shopping': _shopping,
    'shopping_mall': _shopping,
    'mall': _shopping,
    'market': _shopping,
    'history': {'history', 'museum', 'shrine', 'temple', 'historic'},
    'historic': {'history', 'museum', 'shrine', 'temple', 'historic'},
    'shrine': {'history', 'shrine'},
    'temple': {'history', 'temple'},
  };

  String normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Set<String> expand(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return const {};
    return _synonyms[normalized] ?? {normalized};
  }

  Set<String> expandAll(Iterable<String> values) {
    return values.expand(expand).toSet();
  }
}
