/// Source facts, not a quality verdict. Missing tags remain unknown.
/// Lifecycle tags are kept verbatim so conflicting or partial data is not
/// accidentally presented as proof that a venue is open or closed.
class PlaceEvidence {
  final Map<String, String> osmTags;

  const PlaceEvidence.empty() : osmTags = const {};

  PlaceEvidence.fromOsmTags(Object? value)
    : osmTags = Map.unmodifiable({
        if (value is Map)
          for (final entry in value.entries)
            if (entry.key is String &&
                entry.value is String &&
                (entry.value as String).trim().isNotEmpty)
              entry.key as String: entry.value as String,
      });

  String? get openingHours => osmTags['opening_hours'];
  String? get access => osmTags['access'];
  String? get website => osmTags['website'] ?? osmTags['contact:website'];
  String? get wikidata => osmTags['wikidata'];
  String? get wikipedia => osmTags['wikipedia'];

  Map<String, dynamic> toMap() => {'osmTags': Map<String, String>.of(osmTags)};

  factory PlaceEvidence.fromMap(Object? value) =>
      PlaceEvidence.fromOsmTags(value is Map ? value['osmTags'] : null);
}
