import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../models/hotel_stay.dart';
import '../../../models/planner_result.dart';
import 'map_search_area.dart';

/// Temporary UI state used until the multi-destination TripViewModel contract
/// is merged. Keeping this under views prevents the UI branch from owning
/// persistence or planner-domain models.
class DestinationDraft {
  DestinationDraft({
    required this.id,
    required this.destination,
    required this.budget,
    this.placeId,
    this.dates,
    this.selectedPlan = 'Balanced',
    this.plannerResult,
    this.hotelRecommendations = const [],
    this.selectedHotel,
    this.placeDataSource = '',
    this.savedDays = const [],
    this.startTimeOverrides = const {},
    this.undoDays = const [],
    this.undoBudget,
    this.undoStyle,
    this.mapSearchArea,
    this.currencyCode = Money.defaultCurrencyCode,
  });

  final String id;
  String destination;

  /// Google placeId for [destination]. When present, planning resolves the
  /// map center from Google directly instead of geocoding the text, which is
  /// what keeps cities like Đà Lạt from landing on their parent province.
  String? placeId;

  double budget;
  DateTimeRange? dates;
  String selectedPlan;
  PlannerResult? plannerResult;
  List<HotelStay> hotelRecommendations;
  HotelStay? selectedHotel;
  String placeDataSource;
  List<PlannerDay> savedDays;
  Map<String, int> startTimeOverrides;
  List<PlannerDay> undoDays;
  double? undoBudget;
  String? undoStyle;
  MapSearchArea? mapSearchArea;

  /// Currency this destination's amounts are in. Set from the calibration when
  /// a plan is generated, so a Da Lat leg can be in dong while a Tokyo leg is
  /// in yen. Totals are never summed across differing currencies.
  String currencyCode;

  List<PlannerDay> get days => plannerResult?.days ?? savedDays;

  int get dayCount =>
      plannerResult?.days.length ??
      (dates == null ? 0 : dates!.end.difference(dates!.start).inDays + 1);

  /// Per-person schedule cost plus the hotel, which is already a party total.
  /// Prefer [estimatedTotalFor] anywhere a user sees the number.
  double get estimatedTotal =>
      days.fold<double>(0, (sum, day) => sum + day.estimatedCost) +
      (selectedHotel?.totalCost ?? 0);

  double estimatedTotalFor(int travelers) =>
      days.fold<double>(
        0,
        (sum, day) => sum + day.estimatedCostFor(travelers),
      ) +
      (selectedHotel?.totalCost ?? 0);
}
