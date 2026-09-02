import 'package:flutter_test/flutter_test.dart';

import 'package:travel/models/hotel_selections.dart';
import 'package:travel/models/trip/trip_segment.dart';
import 'package:travel/models/trip/travel_leg.dart';
import 'package:travel/viewmodels/trip_viewmodel.dart';

void main() {
  group('TripViewModel multi-destination state', () {
    test('adds and selects destinations independently', () {
      final vm = TripViewModel.forSegmentTesting();

      final daNang = TripSegment(
        id: 'da-nang',
        destination: 'Da Nang',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 12),
        allocatedBudget: 800,
      );

      final hcm = TripSegment(
        id: 'hcm',
        destination: 'Ho Chi Minh City',
        startDate: DateTime(2026, 9, 13),
        endDate: DateTime(2026, 9, 15),
        allocatedBudget: 1000,
      );

      vm.addSegment(daNang);
      expect(vm.draftSegments.length, 1);
      expect(vm.selectedSegment?.destination, 'Da Nang');

      vm.addSegment(hcm);
      expect(vm.draftSegments.length, 2);
      expect(vm.selectedSegment?.destination, 'Ho Chi Minh City');

      vm.selectSegment('da-nang');
      expect(vm.selectedSegment?.destination, 'Da Nang');
    });

    test('each destination keeps a different hotel', () {
      final vm = TripViewModel.forSegmentTesting();

      vm.addSegment(
        TripSegment(
          id: 'da-nang',
          destination: 'Da Nang',
          startDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 9, 12),
          allocatedBudget: 800,
        ),
      );

      vm.addSegment(
        TripSegment(
          id: 'hcm',
          destination: 'Ho Chi Minh City',
          startDate: DateTime(2026, 9, 13),
          endDate: DateTime(2026, 9, 15),
          allocatedBudget: 1000,
        ),
      );

      vm.updateSegmentHotel(
        'da-nang',
        const HotelSelection(
          name: 'Da Nang Hotel',
          address: 'Da Nang',
          nightlyPrice: 80,
          nights: 3,
        ),
      );

      vm.updateSegmentHotel(
        'hcm',
        const HotelSelection(
          name: 'HCM Hotel',
          address: 'Ho Chi Minh City',
          nightlyPrice: 120,
          nights: 3,
        ),
      );

      vm.selectSegment('da-nang');
      expect(vm.selectedSegment?.hotel?.name, 'Da Nang Hotel');

      vm.selectSegment('hcm');
      expect(vm.selectedSegment?.hotel?.name, 'HCM Hotel');
    });

    test('saved state belongs to only one destination', () {
      final vm = TripViewModel.forSegmentTesting();

      vm.addSegment(
        TripSegment(
          id: 'da-nang',
          destination: 'Da Nang',
          startDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 9, 12),
          allocatedBudget: 800,
        ),
      );

      vm.addSegment(
        TripSegment(
          id: 'hcm',
          destination: 'Ho Chi Minh City',
          startDate: DateTime(2026, 9, 13),
          endDate: DateTime(2026, 9, 15),
          allocatedBudget: 1000,
        ),
      );

      vm.markSegmentSaved('da-nang');

      final daNang = vm.draftSegments.firstWhere(
        (segment) => segment.id == 'da-nang',
      );

      final hcm = vm.draftSegments.firstWhere((segment) => segment.id == 'hcm');

      expect(daNang.scheduleSaved, true);
      expect(hcm.scheduleSaved, false);
    });

    test('keeps travel legs and user overrides while the page is closed', () {
      final vm = TripViewModel.forSegmentTesting();
      final leg = TravelLegDraft(
        fromDestinationId: 'hue',
        toDestinationId: 'da-nang',
        estimate: const TravelEstimate(
          mode: TravelMode.driving,
          distanceKm: 94,
          durationHours: 2.5,
          originLatitude: 16.46,
          originLongitude: 107.59,
          destinationLatitude: 16.05,
          destinationLongitude: 108.20,
        ),
        overrideDurationHours: 3,
      );

      vm.replaceTravelLegs([leg]);

      expect(vm.draftTravelLegs.single.durationHours, 3);
      expect(vm.draftTravelLegs.single.isOverridden, isTrue);
    });
  });
}
