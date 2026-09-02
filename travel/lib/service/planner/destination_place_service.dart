import '../../models/travel_place.dart';
import '../../models/hotel_stay.dart';
import '../map_service.dart';
import 'travel_place_mapper.dart';

class DestinationCandidates {
  final Coordinates center;
  final List<TravelPlace> places;
  final List<HotelStay> hotels;

  const DestinationCandidates({
    required this.center,
    required this.places,
    required this.hotels,
  });
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
    'bakery',
    'meal_takeaway',
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
    final hotelResults = await mapService.getNearbyPlaces(
      latitude: center.latitude,
      longitude: center.longitude,
      radius: radiusMeters,
      type: 'hotel',
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
      hotels:
          hotelResults
              .where(
                (hotel) =>
                    hotel.placeId.isNotEmpty && hotel.name.trim().isNotEmpty,
              )
              .map(
                (hotel) => HotelStay(
                  id: hotel.placeId,
                  name: hotel.name,
                  address: hotel.address,
                  latitude: hotel.latitude,
                  longitude: hotel.longitude,
                  rating: hotel.rating,
                  nightlyRate: 0,
                  nights: 1,
                  rooms: 1,
                ),
              )
              .toList()
            ..sort((left, right) => right.rating.compareTo(left.rating)),
    );
  }
}
