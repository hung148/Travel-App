import 'package:cloud_firestore/cloud_firestore.dart';

import '../hotel_selections.dart';
import '../planner_result.dart';

class TripSegment {
  final String id;
  final String destination;

  /// Google placeId for [destination], kept so a reloaded trip resolves the
  /// same map center that was used when the destination was picked.
  final String? destinationPlaceId;
  final DateTime startDate;
  final DateTime endDate;
  final double allocatedBudget;
  final HotelSelection? hotel;
  final List<PlannerDay> days;
  final Map<String, int> startTimeOverrides;
  final List<PlannerDay> undoDays;
  final double? undoBudget;
  final String? undoStyle;
  final double? searchCenterLatitude;
  final double? searchCenterLongitude;
  final int? searchRadiusMeters;

  const TripSegment({
    required this.id,
    required this.destination,
    this.destinationPlaceId,
    required this.startDate,
    required this.endDate,
    required this.allocatedBudget,
    this.hotel,
    this.days = const [],
    this.startTimeOverrides = const {},
    this.undoDays = const [],
    this.undoBudget,
    this.undoStyle,
    this.searchCenterLatitude,
    this.searchCenterLongitude,
    this.searchRadiusMeters,
  });

  int get numberOfDays {
    return endDate.difference(startDate).inDays + 1;
  }

  double get hotelCost {
    return hotel?.totalPrice ?? 0;
  }

  // Per-person totals. Place costs are per person, so these are too.

  double get scheduleCost {
    return days.fold(0, (total, day) => total + day.estimatedCost);
  }

  double get foodCost {
    return days.fold(0, (total, day) => total + day.estimatedFoodCost);
  }

  double get activityCost {
    return days.fold(0, (total, day) => total + day.estimatedActivityCost);
  }

  // Party totals. These are what a user is shown or what gets compared
  // against a budget.

  double scheduleCostFor(int travelers) => days.fold(
        0,
        (total, day) => total + day.estimatedCostFor(travelers),
      );

  double foodCostFor(int travelers) => days.fold(
        0,
        (total, day) => total + day.estimatedFoodCostFor(travelers),
      );

  double activityCostFor(int travelers) => days.fold(
        0,
        (total, day) => total + day.estimatedActivityCostFor(travelers),
      );

  /// The hotel is already a party total; the schedule is not.
  double estimatedTotalCostFor(int travelers) =>
      hotelCost + scheduleCostFor(travelers);

  TripSegment copyWith({
    String? id,
    String? destination,
    String? destinationPlaceId,
    DateTime? startDate,
    DateTime? endDate,
    double? allocatedBudget,
    HotelSelection? hotel,
    List<PlannerDay>? days,
    Map<String, int>? startTimeOverrides,
    List<PlannerDay>? undoDays,
    double? undoBudget,
    String? undoStyle,
    double? searchCenterLatitude,
    double? searchCenterLongitude,
    int? searchRadiusMeters,
  }) {
    return TripSegment(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      destinationPlaceId: destinationPlaceId ?? this.destinationPlaceId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      hotel: hotel ?? this.hotel,
      days: days ?? this.days,
      startTimeOverrides: startTimeOverrides ?? this.startTimeOverrides,
      undoDays: undoDays ?? this.undoDays,
      undoBudget: undoBudget ?? this.undoBudget,
      undoStyle: undoStyle ?? this.undoStyle,
      searchCenterLatitude:
          searchCenterLatitude ?? this.searchCenterLatitude,
      searchCenterLongitude:
          searchCenterLongitude ?? this.searchCenterLongitude,
      searchRadiusMeters: searchRadiusMeters ?? this.searchRadiusMeters,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'destination': destination,
      'destinationPlaceId': destinationPlaceId,
      'startDate': startDate,
      'endDate': endDate,
      'allocatedBudget': allocatedBudget,
      'hotel': hotel?.toMap(),
      'days': days.map((day) => day.toMap()).toList(),
      'startTimeOverrides': startTimeOverrides,
      'undoDays': undoDays.map((day) => day.toMap()).toList(),
      'undoBudget': undoBudget,
      'undoStyle': undoStyle,
      'searchCenterLatitude': searchCenterLatitude,
      'searchCenterLongitude': searchCenterLongitude,
      'searchRadiusMeters': searchRadiusMeters,
    };
  }

  factory TripSegment.fromMap(Map<String, dynamic> data) {
    final hotelData = data['hotel'];
    final dayList = data['days'] as List<dynamic>? ?? const [];
    final undoDayList = data['undoDays'] as List<dynamic>? ?? const [];

    return TripSegment(
      id: data['id'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      destinationPlaceId: data['destinationPlaceId'] as String?,
      startDate: _dateFromFirestore(data['startDate']) ?? DateTime(1970),
      endDate: _dateFromFirestore(data['endDate']) ?? DateTime(1970),
      allocatedBudget: (data['allocatedBudget'] as num?)?.toDouble() ?? 0,
      hotel: hotelData is Map
          ? HotelSelection.fromMap(Map<String, dynamic>.from(hotelData))
          : null,
      days: dayList
          .whereType<Map>()
          .map((day) => PlannerDay.fromMap(Map<String, dynamic>.from(day)))
          .toList(),
      startTimeOverrides:
          (data['startTimeOverrides'] as Map<dynamic, dynamic>? ?? const {})
              .map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toInt()),
              ),
      undoDays: undoDayList
          .whereType<Map>()
          .map((day) => PlannerDay.fromMap(Map<String, dynamic>.from(day)))
          .toList(),
      undoBudget: (data['undoBudget'] as num?)?.toDouble(),
      undoStyle: data['undoStyle'] as String?,
      searchCenterLatitude:
          (data['searchCenterLatitude'] as num?)?.toDouble(),
      searchCenterLongitude:
          (data['searchCenterLongitude'] as num?)?.toDouble(),
      searchRadiusMeters: (data['searchRadiusMeters'] as num?)?.toInt(),
    );
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
