class MapSearchArea {
  const MapSearchArea({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final double latitude;
  final double longitude;
  final int radiusMeters;

  String get radiusLabel {
    final kilometers = radiusMeters / 1000;
    return kilometers == kilometers.roundToDouble()
        ? '${kilometers.toStringAsFixed(0)} km'
        : '${kilometers.toStringAsFixed(1)} km';
  }
}
