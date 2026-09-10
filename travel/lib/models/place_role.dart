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

/// A shopping stop is a mall or a large market - Chợ Đà Lạt, Bến Thành, a
/// night market. Both are places you spend an afternoon in.
///
/// `department_store` was tried here and taken back out: the big Vietnamese
/// electronics chains (Điện Máy Xanh, Nguyễn Kim) register under it, so it put
/// appliance shops in the plan. Do not add it back.
const majorShoppingTypes = <String>{'shopping_mall', 'market'};

/// Places that sell one kind of thing, or sell groceries. A weekly shop is
/// not sightseeing, so `supermarket` is as unwelcome here as `shoe_store`.
const _narrowRetailTypes = <String>{
  'supermarket',
  'wholesaler',
  'warehouse_store',
};

/// True when this type set describes an actual mall or market.
///
/// Google attaches `shopping_mall` to plenty of single shops, so the type list
/// on its own is not enough. Two signals give a shop away: its [primaryType]
/// stays `shoe_store` no matter what else it lists, and a narrow `*_store`
/// type sits next to the mall claim.
bool isMajorShoppingPlace(Iterable<String> types, {String primaryType = ''}) {
  final normalized = types.map((type) => type.toLowerCase().trim()).toSet();
  final primary = primaryType.toLowerCase().trim();

  // When Google gives a primary type it is the authority, and the secondary
  // types are ignored on purpose. A real mall lists half the retail catalogue
  // among its types - Vincom carries `department_store`, Lotte carries
  // `supermarket` - so rejecting on a secondary `*_store` threw out the big
  // malls while a shophouse with one lonely `shopping_mall` type sailed
  // through. The primary type is the one the owner had to choose.
  if (primary.isNotEmpty) return majorShoppingTypes.contains(primary);

  // No primary type: saved plans and older fixtures. Fall back to the
  // conservative reading, where a narrow retail type does disqualify.
  if (!normalized.any(majorShoppingTypes.contains)) return false;
  return !normalized.any(
    (type) => type.endsWith('_store') || _narrowRetailTypes.contains(type),
  );
}

/// Errands, not stops. Google hands these back inside ordinary searches - a
/// landmark post office comes through `tourist_attraction`, a bank through
/// `point_of_interest` - and no traveler wants one in an itinerary.
const nonItineraryTypes = <String>{
  'post_office',
  'bank',
  'atm',
  'city_hall',
  'courthouse',
  'embassy',
  'police',
  'fire_station',
  'local_government_office',
  'hospital',
  'doctor',
  'dentist',
  'pharmacy',
  'drugstore',
  'veterinary_care',
  'gas_station',
  'electric_vehicle_charging_station',
  'car_repair',
  'car_wash',
  'car_dealer',
  'car_rental',
  'parking',
  'storage',
  'moving_company',
  'insurance_agency',
  'real_estate_agency',
  'lawyer',
  'accounting',
  'electrician',
  'plumber',
  'funeral_home',
  'cemetery',
  'telecommunications_service_provider',
  'corporate_office',
  'school',
  'primary_school',
  'secondary_school',
};

/// True for a service or civic building that is never an itinerary stop.
bool isNonItineraryPlace(Iterable<String> types) {
  return types
      .map((type) => type.toLowerCase().trim())
      .any(nonItineraryTypes.contains);
}

/// Any retail business, mall or single shop. Used to route a candidate into
/// the shopping bucket before it is judged.
bool isRetailPlace(Iterable<String> types) {
  final normalized = types.map((type) => type.toLowerCase().trim()).toSet();
  return normalized.contains('store') ||
      normalized.any((type) => type.endsWith('_store')) ||
      normalized.any(_narrowRetailTypes.contains) ||
      normalized.any(majorShoppingTypes.contains);
}

/// Whether the traveler asked for shopping, in any of the words the app uses
/// for it. Decides how much of the candidate pool shopping is allowed to take.
bool wantsShopping(Iterable<String> normalizedStyleTags) {
  const shoppingTerms = {'shopping', 'shopping_mall', 'mall', 'market'};
  return normalizedStyleTags.any(shoppingTerms.contains);
}
