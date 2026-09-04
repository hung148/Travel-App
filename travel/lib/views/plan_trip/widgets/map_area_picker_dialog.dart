import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_search_area.dart';

class MapAreaPickerDialog extends StatefulWidget {
  const MapAreaPickerDialog({
    super.key,
    required this.destination,
    required this.initialCenter,
    this.initialArea,
  });

  final String destination;
  final LatLng initialCenter;
  final MapSearchArea? initialArea;

  @override
  State<MapAreaPickerDialog> createState() => _MapAreaPickerDialogState();
}

class _MapAreaPickerDialogState extends State<MapAreaPickerDialog> {
  late LatLng _center;
  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    final initialArea = widget.initialArea;
    _center = initialArea == null
        ? widget.initialCenter
        : LatLng(initialArea.latitude, initialArea.longitude);
    _radiusKm = (initialArea?.radiusMeters ?? 5000) / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 700;

    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close area picker',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DRAW YOUR TRAVEL ZONE',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                        ),
                        Text(
                          widget.destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  if (!compact) _confirmButton(),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: 12,
                        minZoom: 3,
                        maxZoom: 18,
                        onTap: (_, point) => setState(() => _center = point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.travelplanner.travel',
                          maxNativeZoom: 19,
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _center,
                              radius: _radiusKm * 1000,
                              useRadiusInMeter: true,
                              color: colors.primary.withValues(alpha: 0.16),
                              borderColor: colors.primary,
                              borderStrokeWidth: 3,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _center,
                              width: 54,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.surface,
                                    width: 4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_searching_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        RichAttributionWidget(
                          attributions: const [
                            TextSourceAttribution('OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.radio_button_checked,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Search radius',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  '${_radiusKm.toStringAsFixed(_radiusKm == _radiusKm.roundToDouble() ? 0 : 1)} km',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _radiusKm,
                              min: 1,
                              max: 20,
                              divisions: 38,
                              label: '${_radiusKm.toStringAsFixed(1)} km',
                              onChanged: (value) =>
                                  setState(() => _radiusKm = value),
                            ),
                            Text(
                              'Tap anywhere to move the center. Only places inside the brown circle will be considered.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                            if (compact) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: _confirmButton(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmButton() => FilledButton.icon(
        onPressed: () => Navigator.pop(
          context,
          MapSearchArea(
            latitude: _center.latitude,
            longitude: _center.longitude,
            radiusMeters: (_radiusKm * 1000).round(),
          ),
        ),
        icon: const Icon(Icons.check_rounded),
        label: const Text('Use this area'),
      );
}
