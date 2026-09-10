import '../../models/place_role.dart';
import '../../models/travel_place.dart';

class PlaceRoleClassifier {
  const PlaceRoleClassifier();

  PlaceRole classify(TravelPlace place) {
    if (place.isDining) return PlaceRole.dining;
    if (_natureTypes.contains(place.category)) return PlaceRole.nature;
    if (_entertainmentTypes.contains(place.category)) {
      return PlaceRole.entertainment;
    }
    if (_shoppingTypes.contains(place.category)) return PlaceRole.shopping;
    if (_sightseeingTypes.contains(place.category)) {
      return PlaceRole.sightseeing;
    }
    final types = {
      place.category,
      ...place.tags,
    }.map((type) => type.toLowerCase().trim()).toSet();

    if (types.any(_cultureTypes.contains)) return PlaceRole.culture;
    if (types.any(_natureTypes.contains)) return PlaceRole.nature;
    if (types.any(_entertainmentTypes.contains)) {
      return PlaceRole.entertainment;
    }
    if (types.any(_shoppingTypes.contains)) return PlaceRole.shopping;
    if (types.any(_sightseeingTypes.contains)) return PlaceRole.sightseeing;
    return PlaceRole.other;
  }

  Set<String> preferenceTerms(PlaceRole role) {
    return switch (role) {
      PlaceRole.dining => const {'dining', 'food', 'local_food', 'restaurant'},
      PlaceRole.sightseeing => const {
        'sightseeing',
        'tourist_attraction',
        'landmark',
      },
      PlaceRole.culture => const {
        'culture',
        'museum',
        'history',
        'art_gallery',
      },
      PlaceRole.nature => const {'nature', 'park', 'beach', 'garden'},
      PlaceRole.entertainment => const {
        'entertainment',
        'nightlife',
        'amusement_park',
      },
      PlaceRole.shopping => const {
        'shopping',
        'shopping_mall',
        'market',
        'mall',
      },
      PlaceRole.other => const {},
    };
  }

  static const _cultureTypes = {
    'museum',
    'art_gallery',
    'cultural_center',
    'historical_landmark',
    'place_of_worship',
    'church',
    'hindu_temple',
    'mosque',
    'synagogue',
  };
  static const _natureTypes = {
    'park',
    'national_park',
    'beach',
    'botanical_garden',
    'garden',
    'garden_center',
    'hiking_area',
  };
  static const _entertainmentTypes = {
    'amusement_park',
    'aquarium',
    'bowling_alley',
    'casino',
    'movie_theater',
    'night_club',
    'performing_arts_theater',
    'concert_hall',
    'comedy_club',
    'bar',
    'stadium',
    'zoo',
  };
  static const _shoppingTypes = majorShoppingTypes;
  static const _sightseeingTypes = {
    'tourist_attraction',
    'landmark',
    'observation_deck',
    'monument',
    'historical_place',
  };
}
