import 'package:flutter/material.dart';

import '../../../models/hotel_stay.dart';
import '../../../models/planner_result.dart';

/// Temporary UI state used until the multi-destination TripViewModel contract
/// is merged. Keeping this under views prevents the UI branch from owning
/// persistence or planner-domain models.
class DestinationDraft {
  DestinationDraft({
    required this.id,
    required this.destination,
    required this.budget,
    this.dates,
    this.selectedPlan = 'Balanced',
    this.plannerResult,
    this.hotelRecommendations = const [],
    this.selectedHotel,
    this.scheduleSaved = false,
    this.placeDataSource = '',
  });

  final String id;
  String destination;
  double budget;
  DateTimeRange? dates;
  String selectedPlan;
  PlannerResult? plannerResult;
  List<HotelStay> hotelRecommendations;
  HotelStay? selectedHotel;
  bool scheduleSaved;
  String placeDataSource;

  int get dayCount =>
      plannerResult?.days.length ??
      (dates == null ? 0 : dates!.end.difference(dates!.start).inDays + 1);

  double get estimatedTotal => plannerResult?.totalEstimatedTripCost ?? 0;
}
