class HotelSelection {
  final String? placeId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  /// User-entered or estimated nightly cost.
  final double? nightlyPrice;

  final int nights;

  const HotelSelection({
    this.placeId,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.nightlyPrice,
    required this.nights,
  });

  double? get totalPrice {
    if (nightlyPrice == null) return null;
    return nightlyPrice! * nights;
  }

  HotelSelection copyWith({
    String? placeId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? nightlyPrice,
    int? nights,
  }) {
    return HotelSelection(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      nightlyPrice: nightlyPrice ?? this.nightlyPrice,
      nights: nights ?? this.nights,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'nightlyPrice': nightlyPrice,
      'nights': nights,
    };
  }

  factory HotelSelection.fromMap(Map<String, dynamic> data) {
    return HotelSelection(
      placeId: data['placeId'] as String?,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      nightlyPrice: (data['nightlyPrice'] as num?)?.toDouble(),
      nights: (data['nights'] as num?)?.toInt() ?? 0,
    );
  }
}
