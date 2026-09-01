import '../../models/travel_place.dart';
import '../map_service.dart';
import 'travel_place_mapper.dart';

class DestinationCandidates {
  final Coordinates center;
  final List<TravelPlace> places;

  const DestinationCandidates({required this.center, required this.places});
}

class DestinationPlaceService {
  final MapService mapService;
  final TravelPlaceMapper mapper;

  const DestinationPlaceService({
    required this.mapService,
    this.mapper = const TravelPlaceMapper(),
  });

  static const _candidateTypes = [
    'tourist_attraction',
    'museum',
    'park',
    'cafe',
    'restaurant',
    'shopping_mall',
  ];

  static const _accommodationTypes = {
    'lodging',
    'hotel',
    'hostel',
    'motel',
    'bed_and_breakfast',
    'guest_house',
    'resort_hotel',
    'extended_stay_hotel',
  };

  Future<DestinationCandidates> loadForDestination(
    String destination, {
    int radiusMeters = 15000,
  }) async {
    final center = await mapService.geocodeAddress(destination);
    final searches = await Future.wait(
      _candidateTypes.map(
        (type) => mapService.getNearbyPlaces(
          latitude: center.latitude,
          longitude: center.longitude,
          radius: radiusMeters,
          type: type,
        ),
      ),
    );

    final uniquePlaces = <String, NearbyPlace>{};
    for (final nearbyPlace in searches.expand((places) => places)) {
      if (nearbyPlace.placeId.isEmpty || nearbyPlace.name.trim().isEmpty) {
        continue;
      }
      if (nearbyPlace.types.any(_accommodationTypes.contains)) {
        continue;
      }
      uniquePlaces.putIfAbsent(nearbyPlace.placeId, () => nearbyPlace);
    }

    return DestinationCandidates(
      center: center,
      places: uniquePlaces.values.map(mapper.fromNearbyPlace).toList(),
    );
  }
}
