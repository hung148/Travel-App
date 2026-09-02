class HotelStay {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final double nightlyRate;
  final int nights;
  final int rooms;
  final bool userProvided;

  const HotelStay({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.nightlyRate,
    required this.nights,
    required this.rooms,
    this.userProvided = false,
  });

  double get totalCost => nightlyRate * nights * rooms;

  HotelStay copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? rating,
    double? nightlyRate,
    int? nights,
    int? rooms,
    bool? userProvided,
  }) {
    return HotelStay(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      nightlyRate: nightlyRate ?? this.nightlyRate,
      nights: nights ?? this.nights,
      rooms: rooms ?? this.rooms,
      userProvided: userProvided ?? this.userProvided,
    );
  }
}
