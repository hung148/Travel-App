enum TripAiCommandType {
  answer,
  clarify,
  explain,

  /// "Why is the total that much?" - answered from the same CostBreakdown
  /// the breakdown sheet renders, so the two can never disagree.
  explainCost,
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
    this.message,
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

  /// One-line preview of what applying this command would do. Shown next to
  /// the Apply button.
  final String explanation;

  /// Conversational reply for answer, clarify and explain. Null for edits.
  final String? message;

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

  /// Text the chat bubble should show: the conversational reply when there is
  /// one, otherwise the short preview line.
  String get reply {
    final text = message?.trim();
    return (text != null && text.isNotEmpty) ? text : explanation;
  }

  /// True when this reply is prose meant to be read rather than applied.
  bool get isConversation => switch (type) {
    TripAiCommandType.answer ||
    TripAiCommandType.clarify ||
    TripAiCommandType.explain ||
    TripAiCommandType.explainCost => true,
    _ => false,
  };

  TripAiCommand copyWith({
    String? activityName,
    int? dayNumber,
    List<int>? activityNumbers,
    String? explanation,
    String? message,
  }) => TripAiCommand(
    type: type,
    explanation: explanation ?? this.explanation,
    message: message ?? this.message,
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

  /// answer, clarify, explain and unsupported are conversation only, so the
  /// Apply button never appears for them.
  bool get changesTrip => switch (type) {
    TripAiCommandType.answer ||
    TripAiCommandType.clarify ||
    TripAiCommandType.explain ||
    TripAiCommandType.explainCost ||
    TripAiCommandType.unsupported => false,
    _ => true,
  };

  factory TripAiCommand.fromJson(Map<String, dynamic> json) {
    final type = switch (json['command']) {
      'answer' => TripAiCommandType.answer,
      'clarify' => TripAiCommandType.clarify,
      'explain' => TripAiCommandType.explain,
      'explain_cost' => TripAiCommandType.explainCost,
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
    final message = (json['message'] as String?)?.trim();
    return TripAiCommand(
      type: type,
      explanation: (json['explanation'] as String?)?.trim().isNotEmpty == true
          ? (json['explanation'] as String).trim()
          : 'I could not interpret that request safely.',
      message: (message != null && message.isNotEmpty) ? message : null,
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
