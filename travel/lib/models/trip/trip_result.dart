import 'package:travel/models/trip/trip.dart';

// detail error if fail
class TripResult {
    final bool success;
    final Trip? data;
    final String? error;

    const TripResult({
      required this.success,
      required this.data,
      required this.error,
    });
  }