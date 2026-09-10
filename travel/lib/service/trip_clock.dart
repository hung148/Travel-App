import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class TripClock {
  static bool _ready = false;
  static void initialize() {
    if (_ready) return;
    data.initializeTimeZones();
    _ready = true;
  }

  static bool validZone(String? zone) {
    initialize();
    return zone != null && tz.timeZoneDatabase.locations.containsKey(zone);
  }

  static DateTime? localNow(String? zone, {DateTime? now}) {
    if (!validZone(zone)) return null;
    return tz.TZDateTime.from(now ?? DateTime.now(), tz.getLocation(zone!));
  }

  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static DateTime? parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    return date != null && dateKey(date) == value ? date : null;
  }
}
