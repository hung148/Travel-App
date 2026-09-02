import '../hotel_selections.dart';
import '../planner_result.dart';

class TripSegment {
  final String id;

  /// Example: Da Nang, Ho Chi Minh City, Tokyo
  final String destination;

  final DateTime startDate;
  final DateTime endDate;

  /// Amount of the overall trip budget assigned to this destination.
  final double allocatedBudget;

  /// Each destination owns its own hotel.
  final HotelSelection? hotel;

  /// Generated schedule for this destination.
  final List<PlannerDay> days;

  /// True after the user presses "Save Da Nang Schedule", etc.
  final bool scheduleSaved;

  const TripSegment({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.allocatedBudget,
    this.hotel,
    this.days = const [],
    this.scheduleSaved = false,
  });

  int get numberOfDays {
    return endDate.difference(startDate).inDays + 1;
  }

  double get hotelCost {
    return hotel?.totalPrice ?? 0;
  }

  double get scheduleCost {
    return days.fold(
      0,
      (total, day) => total + day.estimatedCost,
    );
  }

  double get estimatedTotalCost {
    return hotelCost + scheduleCost;
  }

  TripSegment copyWith({
    String? id,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? allocatedBudget,
    HotelSelection? hotel,
    List<PlannerDay>? days,
    bool? scheduleSaved,
  }) {
    return TripSegment(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      hotel: hotel ?? this.hotel,
      days: days ?? this.days,
      scheduleSaved: scheduleSaved ?? this.scheduleSaved,
    );
  }
}