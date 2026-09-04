import 'package:cloud_firestore/cloud_firestore.dart';

import '../hotel_selections.dart';
import '../planner_result.dart';

class TripSegment {
  final String id;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double allocatedBudget;
  final HotelSelection? hotel;
  final List<PlannerDay> days;
  final bool scheduleSaved;
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
    required this.startDate,
    required this.endDate,
    required this.allocatedBudget,
    this.hotel,
    this.days = const [],
    this.scheduleSaved = false,
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

  double get scheduleCost {
    return days.fold(0, (total, day) => total + day.estimatedCost);
  }

  double get foodCost {
    return days.fold(0, (total, day) => total + day.estimatedFoodCost);
  }

  double get activityCost {
    return days.fold(0, (total, day) => total + day.estimatedActivityCost);
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
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      hotel: hotel ?? this.hotel,
      days: days ?? this.days,
      scheduleSaved: scheduleSaved ?? this.scheduleSaved,
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
      'startDate': startDate,
      'endDate': endDate,
      'allocatedBudget': allocatedBudget,
      'hotel': hotel?.toMap(),
      'days': days.map((day) => day.toMap()).toList(),
      'scheduleSaved': scheduleSaved,
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
      scheduleSaved: data['scheduleSaved'] as bool? ?? false,
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
