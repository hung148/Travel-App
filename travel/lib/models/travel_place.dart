import 'cost_estimate.dart';
import 'booking_details.dart';
import 'place_evidence.dart';

class TravelPlace {
  String get dataSource => id.startsWith('osm:') ? 'openstreetmap' : isCustom ? 'custom' : 'google';
  final String id;
  final String name;
  final String category;
  final List<String> tags;

  final double rating;
  final int reviewCount;

  final CostEstimate cost;

  /// Search provenance, not a verified star rating or a published price.
  final bool luxuryDiningSearchMatch;
  final bool destinationHighlight;
  /// Published per-person Vietnamese meal price, retained across currency conversion.
  final double? mealPriceVnd;

  final double latitude;
  final double longitude;
  final bool hasLocation;
  final bool isCustom;
  final BookingDetails? booking;

  final int estimatedVisitMinutes;

  /// Up to [MapService.maxPhotosPerPlace] photos, most representative first.
  final List<String> photoUrls;
  final PlaceEvidence evidence;

  const TravelPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    required this.cost,
    this.luxuryDiningSearchMatch = false,
    this.destinationHighlight = false,
    this.mealPriceVnd,
    required this.latitude,
    required this.longitude,
    required this.estimatedVisitMinutes,
    this.photoUrls = const [],
    this.hasLocation = true,
    this.isCustom = false,
    this.booking,
    this.evidence = const PlaceEvidence.empty(),
  });

  /// Planning cost for ONE person, in the trip currency.
  ///
  /// The planner compares this against per-person budget slices, so both sides
  /// of every comparison stay in the same unit. Anything user-facing must go
  /// through [cost] instead, which knows whether the number is honest enough
  /// to print.
  double get estimatedCost => cost.planningAmount;

  /// What the whole party pays for this stop.
  double estimatedCostFor(int travelers) => cost.amountFor(travelers);

  /// The first photo, for the thumbnail.
  String? get photoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  static List<String> _photoUrlsFromMap(Map<String, dynamic> data) {
    final list = data['photoUrls'];
    if (list is List) {
      return list
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final single = data['photoUrl'] as String?;
    return single == null || single.isEmpty ? const [] : [single];
  }

  bool get isDining {
    final types = {category, ...tags}.map((value) => value.toLowerCase());
    return types.any(
      (type) =>
          type == 'restaurant' ||
          type.endsWith('_restaurant') ||
          type == 'cafe' ||
          type == 'bakery' ||
          type == 'meal_takeaway' ||
          type == 'meal_delivery',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dataSource': dataSource,
      'name': name,
      'category': category,
      'tags': tags,
      'rating': rating,
      'reviewCount': reviewCount,
      'cost': cost.toMap(),
      'luxuryDiningSearchMatch': luxuryDiningSearchMatch,
      'destinationHighlight': destinationHighlight,
      'mealPriceVnd': mealPriceVnd,
      'latitude': latitude,
      'longitude': longitude,
      'estimatedVisitMinutes': estimatedVisitMinutes,
      'photoUrls': photoUrls,
      'hasLocation': hasLocation,
      'isCustom': isCustom,
      'booking': booking?.toMap(),
      'evidence': evidence.toMap(),
    };
  }

  factory TravelPlace.fromMap(Map<String, dynamic> data) {
    final costData = data['cost'];

    return TravelPlace(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      tags: (data['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      luxuryDiningSearchMatch: data['luxuryDiningSearchMatch'] == true,
      destinationHighlight: data['destinationHighlight'] == true,
      mealPriceVnd: (data['mealPriceVnd'] as num?)?.toDouble(),
      evidence: PlaceEvidence.fromMap(data['evidence']),
      // Plans saved before costs carried a source stored a bare number.
      cost: costData is Map
          ? CostEstimate.fromMap(Map<String, dynamic>.from(costData))
          : CostEstimate.legacy(
              (data['estimatedCost'] as num?)?.toDouble() ?? 0,
            ),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      estimatedVisitMinutes:
          (data['estimatedVisitMinutes'] as num?)?.toInt() ?? 0,
      // Plans saved before stops had a gallery stored a single photoUrl.
      photoUrls: _photoUrlsFromMap(data),
      hasLocation: data['hasLocation'] as bool? ??
          (data['latitude'] is num && data['longitude'] is num),
      isCustom: data['isCustom'] == true,
      booking: data['booking'] is Map
          ? BookingDetails.fromMap(Map<String, dynamic>.from(data['booking'] as Map)) : null,
    );
  }
}
