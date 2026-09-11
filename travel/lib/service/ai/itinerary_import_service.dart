import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/booking_details.dart';
import '../../models/cost_estimate.dart';
import '../../models/planner_result.dart';
import '../../models/score_place.dart';
import '../../models/travel_place.dart';
import '../trip_clock.dart';

class ItineraryImportService {
  final String endpoint;
  final http.Client _client;
  ItineraryImportService({required this.endpoint, http.Client? client}) : _client = client ?? http.Client();
  void close() => _client.close();

  Future<List<PlannerDay>> importText({required String text, required DateTime start,
    required int dayCount, required String zone, String? token}) async {
    if (endpoint.isEmpty) throw Exception('AI import is not connected. You can still add items manually.');
    final response = await _client.post(Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
      body: jsonEncode({'text': text})).timeout(const Duration(seconds: 55));
    if (response.statusCode != 200) {
      throw Exception(response.statusCode == 429 ? 'AI limit reached. Try again later.' : 'Import failed. Check your connection and sign-in, then retry.');
    }
    final result = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return draftDays(result, start: start, dayCount: dayCount, zone: zone);
  }

  static List<PlannerDay> draftDays(Map<String, dynamic> result, {required DateTime start,
    required int dayCount, required String zone}) {
    final raw = result['items'];
    if (raw is! List || raw.isEmpty || raw.length > 100) throw const FormatException('No itinerary items found');
    final days = List.generate(dayCount, (index) => PlannerDay(dayNumber: index + 1, places: []));
    for (var index = 0; index < raw.length; index++) {
      final item = Map<String, dynamic>.from(raw[index] as Map);
      String string(String key) => item[key] as String? ?? '';
      final date = TripClock.parseDate(string('date'));
      var dayIndex = date == null ? 0 : DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(start.year, start.month, start.day)).inDays;
      final warnings = (item['warnings'] as List? ?? []).whereType<String>().toList();
      if (date == null || dayIndex < 0 || dayIndex >= dayCount) {
        warnings.add('Placed on day 1 for review. Set a date within the trip or move this item.');
        dayIndex = 0;
      }
      final time = string('time');
      final parts = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(time);
      final booking = BookingDetails(localDate: date == null ? null : TripClock.dateKey(date),
        startMinutes: parts == null ? null : int.parse(parts[1]!) * 60 + int.parse(parts[2]!),
        timeZone: zone, address: string('address'), reference: string('reference'),
        provider: string('provider'), contact: string('contact'),
        notes: '${string('notes')}\nSource: ${string('sourceText')}'.trim(), warnings: warnings);
      final place = TravelPlace(id: 'import-${DateTime.now().microsecondsSinceEpoch}-$index',
        name: string('name'), category: 'personal', tags: const [], rating: 0, reviewCount: 0,
        cost: const CostEstimate(low: 0, high: 0, currencyCode: 'USD', basis: CostBasis.perGroup, source: CostSource.unknown),
        latitude: 0, longitude: 0, hasLocation: false, isCustom: true,
        estimatedVisitMinutes: 0, booking: booking);
      days[dayIndex].places.add(ScoredPlace.fromMap({'place': place.toMap()}));
    }
    return days;
  }
}
