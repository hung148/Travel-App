import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Visible on every app route, including saved OSM trips and modal overlays.
class OsmCredit extends StatelessWidget {
  const OsmCredit({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => launchUrl(
          Uri.parse('https://www.openstreetmap.org/copyright'),
          mode: LaunchMode.externalApplication,
        ),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 12),
        ),
      ),
      TextButton(
        onPressed: () => launchUrl(Uri.parse('https://openrouteservice.org/')),
        child: const Text(
          'Routes: openrouteservice',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}
