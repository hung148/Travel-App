enum TripAiCommandType {
  explain,
  changeBudget,
  relaxDay,
  addFood,
  removeMuseums,
  reduceWalking,
  changeStyle,
  removeStop,
  moveStop,
  replaceStop,
  swapStops,
  replaceWithScheduledStop,
  moveStopRelative,
  moveStopTime,
  addStops,
  removeStops,
  setDayStartTime,
  unsupported,
}

class TripAiCommand {
  const TripAiCommand({
    required this.type,
    required this.explanation,
    this.destinationId,
    this.dayNumber,
    this.budget,
    this.style,
    this.activityName,
    this.targetDayNumber,
    this.replacementPreference,
    this.mealType,
    this.activityNumbers = const [],
    this.replacementCriterion,
    this.sourceStop,
    this.targetStop,
    this.startMinutes,
    this.relativePosition,
    this.stopCount,
    this.stopCategory,
  });

  final TripAiCommandType type;
  final String explanation;
  final String? destinationId;
  final int? dayNumber;
  final double? budget;
  final String? style;
  final String? activityName;
  final int? targetDayNumber;
  final String? replacementPreference;
  final String? mealType;
  final List<int> activityNumbers;
  final String? replacementCriterion;
  final TripAiStopReference? sourceStop;
  final TripAiStopReference? targetStop;
  final int? startMinutes;
  final String? relativePosition;
  final int? stopCount;
  final String? stopCategory;

  TripAiCommand copyWith({
    String? activityName,
    int? dayNumber,
    List<int>? activityNumbers,
    String? explanation,
  }) => TripAiCommand(
    type: type,
    explanation: explanation ?? this.explanation,
    destinationId: destinationId,
    dayNumber: dayNumber ?? this.dayNumber,
    budget: budget,
    style: style,
    activityName: activityName ?? this.activityName,
    targetDayNumber: targetDayNumber,
    replacementPreference: replacementPreference,
    mealType: mealType,
    activityNumbers: activityNumbers ?? this.activityNumbers,
    replacementCriterion: replacementCriterion,
    sourceStop: sourceStop,
    targetStop: targetStop,
    startMinutes: startMinutes,
    relativePosition: relativePosition,
    stopCount: stopCount,
    stopCategory: stopCategory,
  );

  bool get changesTrip => switch (type) {
    TripAiCommandType.explain || TripAiCommandType.unsupported => false,
    _ => true,
  };

  factory TripAiCommand.fromJson(Map<String, dynamic> json) {
    final type = switch (json['command']) {
      'explain' => TripAiCommandType.explain,
      'change_budget' => TripAiCommandType.changeBudget,
      'relax_day' => TripAiCommandType.relaxDay,
      'add_food' => TripAiCommandType.addFood,
      'remove_museums' => TripAiCommandType.removeMuseums,
      'reduce_walking' => TripAiCommandType.reduceWalking,
      'change_style' => TripAiCommandType.changeStyle,
      'remove_stop' => TripAiCommandType.removeStop,
      'move_stop' => TripAiCommandType.moveStop,
      'replace_stop' => TripAiCommandType.replaceStop,
      'swap_stops' => TripAiCommandType.swapStops,
      'replace_with_scheduled_stop' =>
        TripAiCommandType.replaceWithScheduledStop,
      'move_stop_relative' => TripAiCommandType.moveStopRelative,
      'move_stop_time' => TripAiCommandType.moveStopTime,
      'add_stops' => TripAiCommandType.addStops,
      'remove_stops' => TripAiCommandType.removeStops,
      'set_day_start_time' => TripAiCommandType.setDayStartTime,
      _ => TripAiCommandType.unsupported,
    };
    final arguments = json['arguments'] is Map
        ? Map<String, dynamic>.from(json['arguments'] as Map)
        : const <String, dynamic>{};
    return TripAiCommand(
      type: type,
      explanation: (json['explanation'] as String?)?.trim().isNotEmpty == true
          ? (json['explanation'] as String).trim()
          : 'I could not interpret that request safely.',
      destinationId: json['destinationId'] as String?,
      dayNumber: (arguments['dayNumber'] as num?)?.toInt(),
      budget: (arguments['budget'] as num?)?.toDouble(),
      style: arguments['style'] as String?,
      activityName: arguments['activityName'] as String?,
      targetDayNumber: (arguments['targetDayNumber'] as num?)?.toInt(),
      replacementPreference: arguments['replacementPreference'] as String?,
      mealType: arguments['mealType'] as String?,
      activityNumbers:
          (arguments['activityNumbers'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((value) => value.toInt())
              .toList(),
      replacementCriterion: arguments['replacementCriterion'] as String?,
      sourceStop: TripAiStopReference.fromJson(arguments['sourceStop']),
      targetStop: TripAiStopReference.fromJson(arguments['targetStop']),
      startMinutes: (arguments['startMinutes'] as num?)?.toInt(),
      relativePosition: arguments['relativePosition'] as String?,
      stopCount: (arguments['stopCount'] as num?)?.toInt(),
      stopCategory: arguments['stopCategory'] as String?,
    );
  }
}

class TripAiStopReference {
  const TripAiStopReference({
    this.dayNumber,
    this.activityNumber,
    this.activityName,
    this.mealType,
  });

  final int? dayNumber;
  final int? activityNumber;
  final String? activityName;
  final String? mealType;

  static TripAiStopReference? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    return TripAiStopReference(
      dayNumber: (json['dayNumber'] as num?)?.toInt(),
      activityNumber: (json['activityNumber'] as num?)?.toInt(),
      activityName: json['activityName'] as String?,
      mealType: json['mealType'] as String?,
    );
  }
}

class TripAiProposal {
  const TripAiProposal({required this.command, required this.summary});

  final TripAiCommand command;
  final String summary;
}
