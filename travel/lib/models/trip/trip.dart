import 'package:cloud_firestore/cloud_firestore.dart';

import 'trip_segment.dart';

class Trip {
  final String id;
  final String ownerId;

  // Old single-destination fields are kept for compatibility.
  final String destination;
  final double budget;
  final int days;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // New multi-destination data.
  final List<TripSegment> segments;

  Trip({
    required this.id,
    required this.ownerId,
    required this.destination,
    required this.budget,
    required this.days,
    required this.status,
    this.startDate,
    this.endDate,
    this.rating,
    this.createdAt,
    this.updatedAt,
    this.segments = const [],
  });

  bool get isMultiDestination => segments.length > 1;

  int get destinationCount => segments.length;

  int get totalSegmentDays =>
      segments.fold(0, (total, segment) => total + segment.numberOfDays);

  double get allocatedSegmentBudget => segments.fold(
        0,
        (total, segment) => total + segment.allocatedBudget,
      );

  double get totalHotelCost =>
      segments.fold(0, (total, segment) => total + segment.hotelCost);

  double get totalFoodCost =>
      segments.fold(0, (total, segment) => total + segment.foodCost);

  double get totalActivityCost =>
      segments.fold(0, (total, segment) => total + segment.activityCost);

  double get estimatedSegmentsCost =>
      segments.fold(0, (total, segment) => total + segment.estimatedTotalCost);

  double get remainingBudget => budget - estimatedSegmentsCost;

  Trip copyWith({
    String? id,
    String? ownerId,
    String? destination,
    double? budget,
    int? days,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TripSegment>? segments,
  }) {
    return Trip(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      destination: destination ?? this.destination,
      budget: budget ?? this.budget,
      days: days ?? this.days,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      segments: segments ?? this.segments,
    );
  }

  factory Trip.fromMap(Map<String, dynamic> data, String id) {
    final segmentList = data['segments'] as List<dynamic>? ?? const [];

    return Trip(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      budget: (data['budget'] as num?)?.toDouble() ?? 0,
      days: (data['days'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'draft',
      startDate: _dateFromFirestore(data['startDate']),
      endDate: _dateFromFirestore(data['endDate']),
      rating: (data['rating'] as num?)?.toInt(),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
      segments: segmentList
          .whereType<Map>()
          .map(
            (segment) => TripSegment.fromMap(
              Map<String, dynamic>.from(segment),
            ),
          )
          .toList(),
    );
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'destination': destination,
      'budget': budget,
      'days': days,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'segments': segments.map((segment) => segment.toMap()).toList(),
    };
  }
}
