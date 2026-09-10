import '../../models/hotel_stay.dart';

class HotelSelectionService {
  const HotelSelectionService();

  HotelStay? select(
    List<HotelStay> hotels, {
    String spendingStyle = 'Normal',
    required int nights,
    required int rooms,
    required double accommodationBudget,
  }) {
    final sized = hotels
        .map((hotel) => hotel.copyWith(nights: nights, rooms: rooms))
        .toList();
    if (sized.isEmpty) return null;
    final affordable = sized
        .where((hotel) => hotel.totalCost <= accommodationBudget + 0.001)
        .toList();
    if (affordable.isEmpty) {
      sized.sort((a, b) => a.totalCost.compareTo(b.totalCost));
      return sized.first;
    }
    affordable.sort((a, b) {
      final quality = (b.rating >= 4 ? 1 : 0).compareTo(a.rating >= 4 ? 1 : 0);
      if (quality != 0) return quality;
      // Prices describe spending tier; guest reviews describe satisfaction.
      // Neither is an official hotel star classification.
      double score(HotelStay hotel) =>
          hotel.rating * 10 +
          (accommodationBudget <= 0
              ? 0
              : hotel.totalCost / accommodationBudget * 40);
      return score(b).compareTo(score(a));
    });
    return affordable.first;
  }
}
