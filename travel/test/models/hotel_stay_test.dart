import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/hotel_stay.dart';

void main() {
  test('calculates room cost across nights and rooms', () {
    const hotel = HotelStay(
      id: 'hotel',
      name: 'Test Hotel',
      address: 'Address',
      latitude: 1,
      longitude: 2,
      rating: 4.5,
      nightlyRate: 120,
      nights: 3,
      rooms: 2,
    );

    expect(hotel.totalCost, 720);
    expect(hotel.copyWith(nightlyRate: 150).totalCost, 900);
  });
}
