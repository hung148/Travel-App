enum PlaceRole {
  dining,
  sightseeing,
  culture,
  nature,
  entertainment,
  shopping,
  other,
}

extension PlaceRoleLabel on PlaceRole {
  String get label => switch (this) {
    PlaceRole.dining => 'Dining',
    PlaceRole.sightseeing => 'Sightseeing',
    PlaceRole.culture => 'Culture',
    PlaceRole.nature => 'Nature',
    PlaceRole.entertainment => 'Entertainment',
    PlaceRole.shopping => 'Shopping',
    PlaceRole.other => 'Local activity',
  };
}
