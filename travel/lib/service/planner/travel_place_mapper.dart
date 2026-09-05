import '../../models/cost_estimate.dart';
import '../../models/price_calibration.dart';
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

  /// Categories that are reliably free to enter, in every country.
  static const _freeCategories = {
    'park',
    'beach',
    'place_of_worship',
    'natural_feature',
  };

  /// With no price signal from Google, guess a LEVEL, never an amount. The
  /// destination's calibration turns that level into money in the right
  /// currency, so there is no per-currency table anywhere in this file.
  static int _fallbackPriceLevel(String category) => switch (category) {
        'cafe' || 'bakery' || 'meal_takeaway' => 1,
        'museum' || 'art_gallery' || 'restaurant' => 2,
        'zoo' || 'amusement_park' || 'aquarium' => 3,
        _ => 2,
      };

  TravelPlace fromNearbyPlace(
    NearbyPlace nearbyPlace, {
    required PriceCalibration calibration,
  }) {
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
      cost: _costEstimate(
        priceRange: nearbyPlace.priceRange,
        priceLevel: nearbyPlace.priceLevel,
        category: category,
        calibration: calibration,
      ),
      latitude: nearbyPlace.latitude,
      longitude: nearbyPlace.longitude,
      estimatedVisitMinutes: _estimatedVisitMinutes(category),
      photoUrls: nearbyPlace.photoUrls,
    );
  }

  CostEstimate _costEstimate({
    required GooglePriceRange? priceRange,
    required int? priceLevel,
    required String category,
    required PriceCalibration calibration,
  }) {
    final currency = calibration.currencyCode;

    // 1. A real published band, already in the currency we are planning in.
    //    Mixing currencies silently is worse than having no number, so a
    //    mismatch falls through instead of being converted.
    if (priceRange != null &&
        priceRange.currencyCode.trim().toUpperCase() == currency &&
        priceRange.high > 0) {
      return CostEstimate(
        low: priceRange.low,
        high: priceRange.high,
        currencyCode: currency,
        source: CostSource.googlePriceRange,
        basis: CostBasis.perPerson,
        priceLevel: priceLevel,
      );
    }

    // 2. Google says it is free.
    if (priceLevel == 0) return CostEstimate.free(currencyCode: currency);

    // 3. Google gave a level but no amount. The band is real data; the amount
    //    attached to it is ours, so it stays unprintable.
    if (priceLevel != null) {
      final band = calibration.bandFor(priceLevel);
      return CostEstimate(
        low: band.low,
        high: band.high,
        currencyCode: currency,
        source: CostSource.googlePriceLevel,
        basis: CostBasis.perPerson,
        priceLevel: priceLevel,
      );
    }

    // 4. A park is genuinely free.
    if (_freeCategories.contains(category)) {
      return CostEstimate.free(currencyCode: currency);
    }

    // 5. No price signal at all. This is the case that used to render as a
    //    confident "$20". It now carries no chip and no printable amount, so
    //    the itinerary row shows nothing - the honest answer.
    if (!calibration.isUsable) {
      return CostEstimate.unknown(currencyCode: currency);
    }

    final band = calibration.bandFor(_fallbackPriceLevel(category));
    return CostEstimate(
      low: band.low,
      high: band.high,
      currencyCode: currency,
      source: CostSource.categoryDefault,
      basis: CostBasis.perPerson,
      priceLevel: null,
    );
  }

  int _estimatedVisitMinutes(String category) {
    if (category == 'restaurant' || category.endsWith('_restaurant')) {
      return 75;
    }

    return switch (category) {
      'cafe' => 45,
      'place_of_worship' => 60,
      'museum' || 'art_gallery' => 120,
      'park' || 'beach' || 'tourist_attraction' => 90,
      'shopping_mall' => 120,
      'zoo' || 'amusement_park' || 'aquarium' => 180,
      _ => 90,
    };
  }
}
