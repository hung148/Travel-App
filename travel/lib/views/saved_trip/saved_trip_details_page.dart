import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/money.dart';
import '../../models/planner_result.dart';
import '../../models/score_place.dart';
import '../../models/trip/trip.dart';
import '../../models/trip/trip_segment.dart';
import '../../service/planner/daily_time_schedule_service.dart';
import '../../viewmodels/trip_viewmodel.dart';
import '../../widgets/place_photo.dart';
import '../community/destination_community_panel.dart';
import '../plan_trip/plan_trip_page.dart';
import '../summary/review_widget.dart';

class SavedTripDetailsPage extends StatefulWidget {
  const SavedTripDetailsPage({
    super.key,
    required this.trip,
    this.initialTab = 0,
  });

  final Trip trip;
  final int initialTab;

  @override
  State<SavedTripDetailsPage> createState() => _SavedTripDetailsPageState();
}

class _SavedTripDetailsPageState extends State<SavedTripDetailsPage> {
  late int _selectedTab = widget.initialTab.clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final segments = trip.segments;
    final plannedStops = segments.fold<int>(
      0,
      (total, segment) =>
          total +
          segment.days.fold<int>(
            0,
            (dayTotal, day) => dayTotal + day.places.length,
          ),
    );
    final remaining = trip.remainingBudget;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFCFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: _TopBar(
                      title: trip.title ?? trip.destination,
                      onBack: () => Navigator.maybePop(context),
                      onEdit: () async {
                        final viewModel = context.read<TripViewModel>();
                        await viewModel.loadTripById(trip.id);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PlanTripPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCard(
                          trip: trip,
                          plannedStops: plannedStops,
                          remaining: remaining,
                        ),
                        const SizedBox(height: 18),
                        _SegmentedTabs(
                          selected: _selectedTab,
                          onChanged: (value) =>
                              setState(() => _selectedTab = value),
                        ),
                        const SizedBox(height: 18),
                        _SelectedTripTab(
                          selected: _selectedTab,
                          trip: trip,
                          segments: segments,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTripTab extends StatelessWidget {
  const _SelectedTripTab({
    required this.selected,
    required this.trip,
    required this.segments,
  });

  final int selected;
  final Trip trip;
  final List<TripSegment> segments;

  @override
  Widget build(BuildContext context) {
    return switch (selected) {
      0 => _OverviewTab(trip: trip),
      1 => _ItineraryTab(
        segments: segments,
        travelers: trip.partySize,
        currencyCode: trip.currencyCode,
      ),
      2 => _MapTab(segments: segments),
      _ => _ReviewTab(trip: trip),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onEdit,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit plan'),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.trip,
    required this.plannedStops,
    required this.remaining,
  });

  final Trip trip;
  final int plannedStops;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final firstPhoto = _firstPhoto(trip);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB99A88), width: 1.35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A211D).withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = _HeroCopy(
            trip: trip,
            plannedStops: plannedStops,
            remaining: remaining,
          );
          final image = _HeroImage(
            title: trip.destination,
            photoUrls: firstPhoto == null ? const [] : [firstPhoto],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [image, const SizedBox(height: 18), content],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: content),
              const SizedBox(width: 22),
              Expanded(flex: 5, child: image),
            ],
          );
        },
      ),
    );
  }

  static String? _firstPhoto(Trip trip) {
    for (final segment in trip.segments) {
      for (final day in segment.days) {
        for (final place in day.places) {
          if (place.place.photoUrls.isNotEmpty) {
            return place.place.photoUrls.first;
          }
        }
      }
    }
    return null;
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.trip,
    required this.plannedStops,
    required this.remaining,
  });

  final Trip trip;
  final int plannedStops;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final title = trip.title?.trim().isNotEmpty == true
        ? trip.title!
        : trip.destination;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('SAVED TRIP'),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.04,
            color: const Color(0xFF201A17),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_dateRange(trip)}  •  ${trip.destinationCount} '
          '${trip.destinationCount == 1 ? 'destination' : 'destinations'}  •  '
          '${trip.partySize} ${trip.partySize == 1 ? 'traveler' : 'travelers'}',
          style: const TextStyle(
            color: Color(0xFF6B5A52),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatPill(
              label: 'Budget',
              value: Money.format(trip.budget, trip.currencyCode),
              icon: Icons.account_balance_wallet_outlined,
            ),
            _StatPill(
              label: 'Estimated',
              value: Money.format(
                trip.estimatedSegmentsCost,
                trip.currencyCode,
              ),
              icon: Icons.receipt_long_outlined,
            ),
            _StatPill(
              label: 'Remaining',
              value: Money.format(remaining, trip.currencyCode),
              icon: remaining >= 0
                  ? Icons.savings_outlined
                  : Icons.warning_amber_rounded,
            ),
            _StatPill(
              label: 'Stops',
              value: '$plannedStops',
              icon: Icons.place_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.title, required this.photoUrls});

  final String title;
  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlacePhoto(
              placeName: title,
              photoUrls: photoUrls,
              width: double.infinity,
              height: 280,
              borderRadius: 8,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(left: 14, bottom: 14, child: _PhotoBadge()),
          ],
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: const [
            Icon(Icons.photo_library_outlined, size: 17),
            SizedBox(width: 7),
            Text('Place photos'),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      (Icons.dashboard_outlined, 'Overview'),
      (Icons.view_day_outlined, 'Itinerary'),
      (Icons.map_outlined, 'Map'),
      (Icons.rate_review_outlined, 'Review'),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1B9AA)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 6) / tabs.length;
          return Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (var index = 0; index < tabs.length; index++)
                SizedBox(
                  width: tabWidth < 120 ? 120 : tabWidth,
                  child: _TabButton(
                    icon: tabs[index].$1,
                    label: tabs[index].$2,
                    selected: selected == index,
                    onTap: () => onChanged(index),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF241C18) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF4C3A32),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF4C3A32),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 860;
        final budget = _BudgetCard(trip: trip);
        final destinations = _DestinationsCard(trip: trip);
        final nextSteps = const _NextStepsCard();

        if (narrow) {
          return Column(
            children: [
              budget,
              const SizedBox(height: 14),
              destinations,
              const SizedBox(height: 14),
              nextSteps,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: budget),
            const SizedBox(width: 14),
            Expanded(child: destinations),
            const SizedBox(width: 14),
            Expanded(child: nextSteps),
          ],
        );
      },
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Hotel', trip.totalHotelCost),
      ('Food', trip.totalFoodCost),
      ('Activities', trip.totalActivityCost),
      ('Remaining', trip.remainingBudget),
    ];
    return _Panel(
      title: 'Budget snapshot',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          for (final row in rows)
            _AmountRow(
              label: row.$1,
              amount: row.$2,
              currencyCode: trip.currencyCode,
              strong: row.$1 == 'Remaining',
            ),
        ],
      ),
    );
  }
}

class _DestinationsCard extends StatelessWidget {
  const _DestinationsCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    if (trip.segments.isEmpty) {
      return _Panel(
        title: 'Destinations',
        icon: Icons.location_city_outlined,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF6B4A3B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                trip.destination.trim().isEmpty
                    ? 'Destination not saved'
                    : trip.destination,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    return _Panel(
      title: 'Destinations',
      icon: Icons.location_city_outlined,
      child: Column(
        children: [
          for (final segment in trip.segments)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4A3B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${trip.segments.indexOf(segment) + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          segment.destination,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${_date(segment.startDate)} - ${_date(segment.endDate)}',
                          style: const TextStyle(color: Color(0xFF6B5A52)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.favorite_border_rounded, 'Favorite must-go places'),
      (Icons.swap_horiz_rounded, 'Replace weak recommendations'),
      (Icons.calendar_month_outlined, 'Export to calendar later'),
    ];
    return _Panel(
      title: 'Next actions',
      icon: Icons.bolt_outlined,
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(item.$1, color: const Color(0xFF6B4A3B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItineraryTab extends StatelessWidget {
  const _ItineraryTab({
    required this.segments,
    required this.travelers,
    required this.currencyCode,
  });

  final List<TripSegment> segments;
  final int travelers;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    if (segments.every((segment) => segment.days.isEmpty)) {
      return const _EmptyState(
        icon: Icons.event_note_outlined,
        title: 'No saved schedule yet',
        message: 'Generate and save a plan to see the full day-by-day trip.',
      );
    }

    var dayOffset = 0;
    final cards = <Widget>[];
    for (final segment in segments) {
      for (final day in segment.days) {
        cards.add(
          _DayCard(
            destination: segment.destination,
            day: day,
            dayNumber: dayOffset + day.dayNumber,
            travelers: travelers,
            currencyCode: currencyCode,
          ),
        );
        cards.add(const SizedBox(height: 14));
      }
      dayOffset += segment.days.length;
    }

    return Column(children: cards);
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.destination,
    required this.day,
    required this.dayNumber,
    required this.travelers,
    required this.currencyCode,
  });

  final String destination;
  final PlannerDay day;
  final int dayNumber;
  final int travelers;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final scheduled = const DailyTimeScheduleService().schedule(day.places);
    return _Panel(
      title: 'Day $dayNumber',
      subtitle: destination,
      icon: Icons.route_outlined,
      trailing: Text(
        Money.format(day.estimatedCostFor(travelers), currencyCode),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      child: Column(
        children: [
          for (var index = 0; index < day.places.length; index++) ...[
            _StopTile(
              index: index + 1,
              time: scheduled[index].formattedStartTime,
              role: scheduled[index].roleLabel,
              place: day.places[index],
              travelers: travelers,
              currencyCode: currencyCode,
            ),
            if (index != day.places.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.index,
    required this.time,
    required this.role,
    required this.place,
    required this.travelers,
    required this.currencyCode,
  });

  final int index;
  final String time;
  final String role;
  final ScoredPlace place;
  final int travelers;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final travelPlace = place.place;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF241C18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        PlacePhoto(
          placeName: travelPlace.name,
          photoUrls: travelPlace.photoUrls,
          width: 78,
          height: 78,
          borderRadius: 8,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF6B4A3B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                travelPlace.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniChip(role),
                  _MiniChip(travelPlace.category.replaceAll('_', ' ')),
                  _MiniChip('${travelPlace.estimatedVisitMinutes} min'),
                  _MiniChip(
                    Money.format(
                      travelPlace.estimatedCostFor(travelers),
                      currencyCode,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Replace later',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI replacement is coming next.')),
          ),
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
      ],
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab({required this.segments});

  final List<TripSegment> segments;

  @override
  Widget build(BuildContext context) {
    final mappedSegments = segments
        .where(
          (segment) =>
              segment.searchCenterLatitude != null &&
              segment.searchCenterLongitude != null,
        )
        .toList();

    if (mappedSegments.isEmpty) {
      return const _EmptyState(
        icon: Icons.map_outlined,
        title: 'Map area not saved yet',
        message:
            'When you plan from a selected map area, this page will show the circle and route context.',
      );
    }

    return _Panel(
      title: 'Map planning areas',
      subtitle: 'Saved search circles and route anchors',
      icon: Icons.radar_outlined,
      child: Column(
        children: [
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EFEA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD1B9AA)),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: _MapGrid()),
                for (var index = 0; index < mappedSegments.length; index++)
                  _MapCircle(index: index, segment: mappedSegments[index]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final segment in mappedSegments) _MapAreaRow(segment: segment),
        ],
      ),
    );
  }
}

class _MapGrid extends StatelessWidget {
  const _MapGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MapGridPainter());
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8C8BD)
      ..strokeWidth = 1;
    for (var x = 24.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x - 36, size.height), paint);
    }
    for (var y = 28.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapCircle extends StatelessWidget {
  const _MapCircle({required this.index, required this.segment});

  final int index;
  final TripSegment segment;

  @override
  Widget build(BuildContext context) {
    final left = 42.0 + (index % 3) * 150;
    final top = 34.0 + (index % 2) * 82;
    return Positioned(
      left: left,
      top: top,
      child: Column(
        children: [
          Container(
            width: 128,
            height: 128,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFB78050).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8B5A3D), width: 2),
            ),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF241C18),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD1B9AA)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                segment.destination,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapAreaRow extends StatelessWidget {
  const _MapAreaRow({required this.segment});

  final TripSegment segment;

  @override
  Widget build(BuildContext context) {
    final radius = segment.searchRadiusMeters == null
        ? 'Custom area'
        : '${(segment.searchRadiusMeters! / 1000).toStringAsFixed(1)} km radius';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.trip_origin_rounded, color: Color(0xFF6B4A3B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              segment.destination,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(radius),
        ],
      ),
    );
  }
}

class _ReviewTab extends StatelessWidget {
  const _ReviewTab({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReviewWidget(trip: trip),
        const SizedBox(height: 14),
        DestinationCommunityPanel(trip: trip, showComposer: false),
        const SizedBox(height: 14),
        _EmptyState(
          icon: Icons.psychology_alt_outlined,
          title: 'Community-powered planning loop',
          message:
              'Public reviews and destination tips turn real traveler experience into better recommendations for the next person.',
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC3A99B), width: 1.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD1B9AA)),
                ),
                child: Icon(icon, color: const Color(0xFF5C4034), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(color: Color(0xFF6B5A52)),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1B9AA)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5C4034), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6B5A52),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF201A17),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    required this.currencyCode,
    this.strong = false,
  });

  final String label;
  final double amount;
  final String currencyCode;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: strong ? FontWeight.w900 : null),
            ),
          ),
          Text(
            Money.format(amount, currencyCode),
            style: TextStyle(fontWeight: strong ? FontWeight.w900 : null),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8C8BD)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6B4A3B),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      icon: icon,
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF6B5A52),
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

String _date(DateTime value) => '${value.month}/${value.day}/${value.year}';

String _dateRange(Trip trip) {
  if (trip.startDate != null && trip.endDate != null) {
    return '${_date(trip.startDate!)} - ${_date(trip.endDate!)}';
  }
  if (trip.segments.isEmpty) return 'Dates not selected';
  return '${_date(trip.segments.first.startDate)} - ${_date(trip.segments.last.endDate)}';
}
