import 'dart:math' as math;

enum TravelMode { driving, flight }

class TravelEstimate {
  const TravelEstimate({
    required this.mode,
    required this.distanceKm,
    required this.durationHours,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final TravelMode mode;
  final double distanceKm;
  final double durationHours;
  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  int get transitDays => durationHours > 24 ? (durationHours / 24).ceil() : 0;
}

class TravelLegDraft {
  TravelLegDraft({
    required this.fromDestinationId,
    required this.toDestinationId,
    required this.estimate,
    this.overrideMode,
    this.overrideDurationHours,
  });

  final String fromDestinationId;
  final String toDestinationId;
  final TravelEstimate estimate;
  TravelMode? overrideMode;
  double? overrideDurationHours;

  TravelMode get mode => overrideMode ?? estimate.mode;
  double get durationHours => overrideDurationHours ?? estimate.durationHours;
  int get transitDays =>
      durationHours > 24 ? math.max(1, (durationHours / 24).ceil()) : 0;
  bool get isOverridden =>
      overrideMode != null || overrideDurationHours != null;
}
