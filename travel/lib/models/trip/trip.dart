import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/money.dart';
import 'trip_segment.dart';

class Trip {
  final String id;
  final String ownerId;
  final String? title;

  // Old single-destination fields are kept for compatibility.
  final String destination;
  final double budget;
  final int days;
  final String status;

  /// Party size. The budget below is the WHOLE party's money, so per-person
  /// costs must be multiplied by this before any comparison against it.
  final int travelers;

  /// Currency the budget and every plan amount is denominated in. One trip is
  /// planned in exactly one currency; nothing is ever converted.
  final String currencyCode;

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
    this.title,
    required this.destination,
    required this.budget,
    required this.days,
    required this.status,
    this.travelers = 1,
    this.currencyCode = Money.defaultCurrencyCode,
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

  double get allocatedSegmentBudget =>
      segments.fold(0, (total, segment) => total + segment.allocatedBudget);

  double get totalHotelCost =>
      segments.fold(0, (total, segment) => total + segment.hotelCost);

  /// Party size, guaranteed to be at least one.
  int get partySize => travelers < 1 ? 1 : travelers;

  double get totalFoodCost => segments.fold(
        0,
        (total, segment) => total + segment.foodCostFor(partySize),
      );

  double get totalActivityCost => segments.fold(
        0,
        (total, segment) => total + segment.activityCostFor(partySize),
      );

  double get estimatedSegmentsCost => segments.fold(
        0,
        (total, segment) => total + segment.estimatedTotalCostFor(partySize),
      );

  double get remainingBudget => budget - estimatedSegmentsCost;

  Trip copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? destination,
    double? budget,
    int? days,
    String? status,
    int? travelers,
    String? currencyCode,
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
      title: title ?? this.title,
      destination: destination ?? this.destination,
      budget: budget ?? this.budget,
      days: days ?? this.days,
      status: status ?? this.status,
      travelers: travelers ?? this.travelers,
      currencyCode: currencyCode ?? this.currencyCode,
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
      title: data['title'] as String?,
      destination: data['destination'] as String? ?? '',
      budget: (data['budget'] as num?)?.toDouble() ?? 0,
      days: (data['days'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'draft',
      travelers: (data['travelers'] as num?)?.toInt() ?? 1,
      currencyCode: Money.normalize(data['currencyCode'] as String?),
      startDate: _dateFromFirestore(data['startDate']),
      endDate: _dateFromFirestore(data['endDate']),
      rating: (data['rating'] as num?)?.toInt(),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
      segments: segmentList
          .whereType<Map>()
          .map(
            (segment) =>
                TripSegment.fromMap(Map<String, dynamic>.from(segment)),
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
      'title': title,
      'destination': destination,
      'budget': budget,
      'days': days,
      'status': status,
      'travelers': travelers,
      'currencyCode': currencyCode,
      'startDate': startDate,
      'endDate': endDate,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'segments': segments.map((segment) => segment.toMap()).toList(),
    };
  }
}
