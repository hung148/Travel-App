import 'score_place.dart';

class ScheduledStop {
  final ScoredPlace scoredPlace;
  final int startMinutes;
  final String roleLabel;

  const ScheduledStop({
    required this.scoredPlace,
    required this.startMinutes,
    required this.roleLabel,
  });

  String get formattedStartTime {
    final hour24 = (startMinutes ~/ 60) % 24;
    final minute = startMinutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}
