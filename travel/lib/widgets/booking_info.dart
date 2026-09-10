import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/travel_place.dart';

Uri? directionsUri(TravelPlace place) => !place.hasLocation ? null : Uri.https(
  'www.google.com', '/maps/dir/', {
    'api': '1', 'destination': '${place.latitude},${place.longitude}',
  });

class BookingInfo extends StatelessWidget {
  final TravelPlace place;
  const BookingInfo({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final booking = place.booking;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(booking?.confirmed == true ? 'Confirmed booking' : 'Suggestion / unconfirmed'),
      if (booking != null) ...[
        if (booking.localDate != null) Text('Date: ${booking.localDate}'),
        if (booking.timeZone != null) Text('Time zone: ${booking.timeZone}'),
        if (booking.address.isNotEmpty) SelectableText('Meeting point: ${booking.address}'),
        if (booking.reference.isNotEmpty) SelectableText('Booking reference: ${booking.reference}'),
        if (booking.provider.isNotEmpty) SelectableText('Provider: ${booking.provider}'),
        if (booking.contact.isNotEmpty) SelectableText('Contact: ${booking.contact}'),
        if (booking.notes.isNotEmpty) SelectableText(booking.notes),
        for (final warning in booking.warnings) Text('Review: $warning'),
      ],
      TextButton.icon(
        icon: const Icon(Icons.directions_outlined),
        label: Text(place.hasLocation ? 'Open directions' : 'Add a location'),
        onPressed: () async {
          final uri = directionsUri(place);
          if (uri == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Open Edit plan, then edit this item to add its coordinates and meeting point.')));
            return;
          }
          try {
            if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
          } catch (_) { /* Show a recoverable failure below. */ }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not open maps. Please try again.')));
          }
        },
      ),
    ]);
  }
}
