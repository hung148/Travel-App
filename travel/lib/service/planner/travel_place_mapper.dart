import '../../models/travel_place.dart';
import '../map_service.dart';

class TravelPlaceMapper {
  const TravelPlaceMapper();

  static const _genericTypes = {
    'point_of_interest',
    'establishment',
    'premise',
    'food',
  };

  TravelPlace fromNearbyPlace(NearbyPlace nearbyPlace) {
    final category = nearbyPlace.types.firstWhere(
      (type) => !_genericTypes.contains(type),
      orElse: () => 'attraction',
    );

    return TravelPlace(
      id: nearbyPlace.placeId,
      name: nearbyPlace.name,
      category: category,
      tags: nearbyPlace.types.toSet().toList(),
      rating: nearbyPlace.rating,
      reviewCount: nearbyPlace.userRatingsTotal,
      estimatedCost: _estimatedCost(
        priceLevel: nearbyPlace.priceLevel,
        category: category,
      ),
      latitude: nearbyPlace.latitude,
      longitude: nearbyPlace.longitude,
      estimatedVisitMinutes: _estimatedVisitMinutes(category),
    );
  }

  double _estimatedCost({required int? priceLevel, required String category}) {
    if (priceLevel != null) {
      return switch (priceLevel) {
        <= 0 => 0,
        1 => 10,
        2 => 25,
        3 => 50,
        _ => 100,
      };
    }

    return switch (category) {
      'park' || 'beach' || 'place_of_worship' => 0,
      'museum' || 'art_gallery' => 15,
      'cafe' => 12,
      'restaurant' => 25,
      _ => 20,
    };
  }

  int _estimatedVisitMinutes(String category) {
    if (category == 'restaurant' || category.endsWith('_restaurant')) {
      return 75;
    }

    return switch (category) {
      'cafe' => 45,
      'restaurant' => 75,
      'place_of_worship' => 60,
      'museum' || 'art_gallery' => 120,
      'park' || 'beach' || 'tourist_attraction' => 90,
      'shopping_mall' || 'store' => 120,
      'zoo' || 'amusement_park' || 'aquarium' => 180,
      _ => 90,
    };
  }
}
