import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/ai/trip_ai_command.dart';

class TripAiException implements Exception {
  const TripAiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TripAiService {
  TripAiService({
    required this.endpoint,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final String endpoint;
  final Duration timeout;
  final http.Client _client;

  static const _notConfigured =
      'The AI service is not connected yet, so I can only handle a few basic '
      'requests such as "make it cheaper" or "relax day 2".';
  static const _unreachable =
      'I could not reach the AI service, so I only understood a few basic '
      'requests. Check your connection and try again.';

  /// The model is the primary interpreter.
  ///
  /// The local keyword matcher below is a degraded offline path only. It must
  /// never run ahead of the model: when it did, any sentence that happened to
  /// contain a trigger word ("why is there a museum on day 2?") was answered by
  /// a regex instead of the AI, which is why paraphrases and questions failed.
  Future<TripAiProposal> propose({
    required String instruction,
    required Map<String, dynamic> context,
    String? idToken,
    List<Map<String, String>> history = const [],
  }) async {
    if (endpoint.trim().isEmpty) {
      return _fallback(instruction, context, _notConfigured);
    }

    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
            body: utf8.encode(
              jsonEncode({
                'instruction': instruction,
                'context': {...context, 'history': history},
              }),
            ),
          )
          .timeout(timeout);
    } on Exception {
      return _fallback(instruction, context, _unreachable);
    }

    if (response.statusCode == 401) {
      throw const TripAiException(
        'Sign in again before using the AI planner.',
        statusCode: 401,
      );
    }
    if (response.statusCode != 200) {
      return _fallback(instruction, context, _unreachable);
    }
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final command = TripAiCommand.fromJson(json);
      return TripAiProposal(command: command, summary: command.reply);
    } on FormatException {
      return _fallback(instruction, context, _unreachable);
    } on TypeError {
      return _fallback(instruction, context, _unreachable);
    }
  }

  TripAiProposal _fallback(
    String instruction,
    Map<String, dynamic> context,
    String notice,
  ) {
    final local = _localProposal(instruction, context);
    if (local.command.type != TripAiCommandType.unsupported) return local;
    final command = TripAiCommand(
      type: TripAiCommandType.unsupported,
      destinationId: context['destinationId'] as String?,
      explanation: notice,
      message: notice,
    );
    return TripAiProposal(command: command, summary: notice);
  }

  TripAiProposal _localProposal(
    String instruction,
    Map<String, dynamic> context,
  ) {
    final text = instruction.toLowerCase().trim();
    final destinationId = context['destinationId'] as String?;
    final placeNames = (context['days'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .expand((day) => (day['places'] as List<dynamic>? ?? const []))
        .map((name) => name.toString())
        .toList();
    final activityName = placeNames
        .where((name) => text.contains(name.toLowerCase()))
        .firstOrNull;
    TripAiCommand command;
    final budget = RegExp(
      r'(?:under|budget(?:\s+(?:of|to))?)\s*\$?\s*([0-9]+(?:\.[0-9]+)?)',
    ).firstMatch(text);
    final day = RegExp(r'day\s+(\d+)').firstMatch(text);
    final mealType = const [
      'breakfast',
      'lunch',
      'dinner',
    ].where(text.contains).firstOrNull;
    final activityNumbers =
        RegExp(r'activit(?:y|ies)\s+([0-9,\sand]+)')
            .firstMatch(text)
            ?.group(1)
            ?.split(RegExp(r'[^0-9]+'))
            .where((value) => value.isNotEmpty)
            .map(int.parse)
            .toList() ??
        const <int>[];
    final closerReplacementRequested = RegExp(
      r'\b(?:find|give|show|get)(?:\s+me)?\s+(?:a\s+)?(?:nearer|closer)\b',
    ).hasMatch(text);
    final replacementRequested =
        text.contains('replace') ||
        text.contains('swap') ||
        text.contains('change') ||
        closerReplacementRequested;
    final replacementCriterion =
        text.contains('closer') || text.contains('nearer')
        ? 'closer'
        : text.contains('cheaper')
        ? 'cheaper'
        : text.contains('higher rated') || text.contains('better rated')
        ? 'higher_rated'
        : text.contains('popular')
        ? 'more_popular'
        : 'best_match';
    final replacementPreference = const [
      'park',
      'museum',
      'restaurant',
      'cafe',
      'nature',
      'shopping',
      'vegetarian',
    ].where(text.contains).firstOrNull;
    final countMatch = RegExp(
      r'(?:add|remove)\s+(\d+)\s+(?:more\s+)?(?:stops?|activities)',
    ).firstMatch(text);
    final startMinutes = _parseTimeMinutes(text);
    final moveNamed = RegExp(
      r'^move\s+(.+?)(?:\s+from\s+day\s+\d+)?\s+to\s+day\s+(\d+)\s*[.!?]*$',
    ).firstMatch(text);
    final swapNumberMeal = RegExp(
      r'^swap\s+activit(?:y|ies)\s+(\d+)\s+(?:on|from)\s+day\s+(\d+)\s+with\s+(breakfast|lunch|dinner)\s+(?:on|from)\s+day\s+(\d+)\s*[.!?]*$',
    ).firstMatch(text);
    final swapNumberActivity = RegExp(
      r'^swap\s+activit(?:y|ies)\s+(\d+)\s+(?:in|on|from)\s+day\s+(\d+)\s+with\s+activit(?:y|ies)\s+(\d+)\s+(?:in|on|from)\s+day\s+(\d+)\s*[.!?]*$',
    ).firstMatch(text);
    final swapAnyStop = RegExp(
      r'^swap\s+(?:activity\s+)?(.+?)\s+(?:in|on|from)\s+day\s+(\d+)\s+with\s+(?:activity\s+)?(.+?)\s+(?:in|on|from)\s+day\s+(\d+)\s*[.!?]*$',
    ).firstMatch(text);
    final scheduledReplacement = RegExp(
      r'^replace\s+activit(?:y|ies)\s+(\d+)\s+(?:on|from)\s+day\s+(\d+)\s+with\s+(.+?)\s+from\s+day\s+(\d+)\s*[.!?]*$',
    ).firstMatch(text);
    final relativeMove = RegExp(
      r'^move\s+(.+?)\s+(before|after)\s+(.+?)\s*[.!?]*$',
    ).firstMatch(text);
    final timedMove = RegExp(
      r'^move\s+(.+?)\s+to\s+(.+?)\s+on\s+day\s+(\d+)\s*[.!?]*$',
    ).firstMatch(text);
    final removeNamed = RegExp(
      r'^(?:remove|delete)\s+(.+?)(?:\s+from\s+(?:the\s+)?itinerary)?\s*[.!?]*$',
    ).firstMatch(text);
    // Tightened: these three used to fire on a bare mention of the word, which
    // turned questions into destructive edits.
    final removeMuseumsRequested = RegExp(
      r'\b(?:no|not|none|remove|delete|avoid|skip|drop|without|less|fewer)\b[^.?!]*\bmuseums?\b',
    ).hasMatch(text);
    final reduceWalkingRequested = RegExp(
      r'\b(?:less|fewer|reduce|shorter|cut|too\s+much|too\s+far|minimi[sz]e|shorten)\b[^.?!]*\b(?:walk\w*|travel\s+time|driving|transit)\b',
    ).hasMatch(text);
    final explainRequested =
        text.contains('explain') ||
        RegExp(r'^(?:why|how come)\b').hasMatch(text);

    if ((text.contains('start time') ||
            RegExp(r'start\s+(?:day\s+\d+\s+)?at').hasMatch(text)) &&
        startMinutes != null) {
      command = TripAiCommand(
        type: TripAiCommandType.setDayStartTime,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        startMinutes: startMinutes,
        explanation: day == null
            ? 'Ask which day should start at the requested time.'
            : 'Reschedule day ${day.group(1)} from the requested start time.',
      );
    } else if (countMatch != null) {
      final adding = text.startsWith('add');
      command = TripAiCommand(
        type: adding
            ? TripAiCommandType.addStops
            : TripAiCommandType.removeStops,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        stopCount: int.parse(countMatch.group(1)!),
        explanation:
            '${adding ? 'Add' : 'Remove'} ${countMatch.group(1)} optional stops safely.',
      );
    } else if (text.contains('busier') ||
        text.contains('more active') ||
        text.contains('pack the schedule')) {
      command = TripAiCommand(
        type: TripAiCommandType.addStops,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        explanation:
            'Add as many safe activities as the time and budget allow.',
      );
    } else if (budget != null ||
        (text.contains('cheaper') && !replacementRequested)) {
      command = TripAiCommand(
        type: TripAiCommandType.changeBudget,
        destinationId: destinationId,
        budget: budget == null ? null : double.tryParse(budget.group(1)!),
        explanation: budget == null
            ? 'Reduce this destination budget by 15% and regenerate it.'
            : 'Set this destination budget to ${budget.group(1)} and '
                  'regenerate it.',
      );
    } else if (const ['relaxed', 'balanced', 'explorer'].any(text.contains) &&
        text.contains('style')) {
      final style = const [
        'Relaxed',
        'Balanced',
        'Explorer',
      ].firstWhere((value) => text.contains(value.toLowerCase()));
      command = TripAiCommand(
        type: TripAiCommandType.changeStyle,
        destinationId: destinationId,
        style: style,
        explanation: 'Use the $style planning style.',
      );
    } else if (swapAnyStop != null) {
      final source = _localStopReference(
        swapAnyStop.group(1)!,
        int.parse(swapAnyStop.group(2)!),
      );
      final target = _localStopReference(
        swapAnyStop.group(3)!,
        int.parse(swapAnyStop.group(4)!),
      );
      if (source != null && target != null) {
        command = TripAiCommand(
          type: TripAiCommandType.swapStops,
          destinationId: destinationId,
          sourceStop: source,
          targetStop: target,
          explanation: 'Swap the two requested stops between their days.',
        );
      } else {
        command = TripAiCommand(
          type: TripAiCommandType.unsupported,
          destinationId: destinationId,
          explanation: 'I could not identify both stops to swap.',
        );
      }
    } else if (swapNumberActivity != null) {
      command = TripAiCommand(
        type: TripAiCommandType.swapStops,
        destinationId: destinationId,
        sourceStop: TripAiStopReference(
          dayNumber: int.parse(swapNumberActivity.group(2)!),
          activityNumber: int.parse(swapNumberActivity.group(1)!),
        ),
        targetStop: TripAiStopReference(
          dayNumber: int.parse(swapNumberActivity.group(4)!),
          activityNumber: int.parse(swapNumberActivity.group(3)!),
        ),
        explanation: 'Swap the two requested activities between their days.',
      );
    } else if (swapNumberMeal != null) {
      command = TripAiCommand(
        type: TripAiCommandType.swapStops,
        destinationId: destinationId,
        sourceStop: TripAiStopReference(
          dayNumber: int.parse(swapNumberMeal.group(2)!),
          activityNumber: int.parse(swapNumberMeal.group(1)!),
        ),
        targetStop: TripAiStopReference(
          dayNumber: int.parse(swapNumberMeal.group(4)!),
          mealType: swapNumberMeal.group(3),
        ),
        explanation: 'Swap the two requested scheduled stops.',
      );
    } else if (scheduledReplacement != null) {
      command = TripAiCommand(
        type: TripAiCommandType.replaceWithScheduledStop,
        destinationId: destinationId,
        sourceStop: TripAiStopReference(
          dayNumber: int.parse(scheduledReplacement.group(2)!),
          activityNumber: int.parse(scheduledReplacement.group(1)!),
        ),
        targetStop: TripAiStopReference(
          dayNumber: int.parse(scheduledReplacement.group(4)!),
          activityName: scheduledReplacement.group(3)!.trim(),
        ),
        explanation: 'Replace the first slot with the other scheduled stop.',
      );
    } else if (relativeMove != null) {
      command = TripAiCommand(
        type: TripAiCommandType.moveStopRelative,
        destinationId: destinationId,
        sourceStop: TripAiStopReference(
          activityName: relativeMove.group(1)!.trim(),
        ),
        targetStop: TripAiStopReference(
          activityName: relativeMove.group(3)!.trim(),
        ),
        relativePosition: relativeMove.group(2),
        explanation: 'Move the requested stop relative to the other stop.',
      );
    } else if (timedMove != null &&
        _parseTimeMinutes(timedMove.group(2)!) != null) {
      command = TripAiCommand(
        type: TripAiCommandType.moveStopTime,
        destinationId: destinationId,
        sourceStop: _localStopReference(timedMove.group(1)!, null),
        targetDayNumber: int.parse(timedMove.group(3)!),
        startMinutes: _parseTimeMinutes(timedMove.group(2)!)!,
        explanation: 'Move the requested stop to the requested day and time.',
      );
    } else if (moveNamed != null) {
      command = TripAiCommand(
        type: TripAiCommandType.moveStop,
        destinationId: destinationId,
        activityName: activityName ?? moveNamed.group(1)!.trim(),
        targetDayNumber: int.parse(moveNamed.group(2)!),
        explanation: 'Move the requested stop and revalidate both days.',
      );
    } else if (replacementRequested &&
        activityNumbers.length == 1 &&
        day != null) {
      command = TripAiCommand(
        type: TripAiCommandType.replaceStop,
        destinationId: destinationId,
        dayNumber: int.tryParse(day.group(1)!),
        activityNumbers: activityNumbers,
        replacementPreference: replacementPreference,
        replacementCriterion: replacementCriterion,
        explanation:
            'Replace activity ${activityNumbers.single} on day ${day.group(1)} with a better available place.',
      );
    } else if (replacementRequested && mealType != null) {
      command = TripAiCommand(
        type: TripAiCommandType.replaceStop,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        mealType: mealType,
        replacementPreference: replacementPreference,
        replacementCriterion: replacementCriterion,
        explanation: day == null
            ? 'Replace $mealType after asking which day.'
            : 'Replace $mealType on day ${day.group(1)} with a better available place.',
      );
    } else if (text.contains('remove') &&
        activityNumbers.isNotEmpty &&
        day != null) {
      command = TripAiCommand(
        type: TripAiCommandType.removeStop,
        destinationId: destinationId,
        dayNumber: int.tryParse(day.group(1)!),
        activityNumbers: activityNumbers,
        explanation:
            'Remove the requested numbered activities from day ${day.group(1)}.',
      );
    } else if (text.contains('remove') && mealType != null) {
      command = TripAiCommand(
        type: TripAiCommandType.removeStop,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        mealType: mealType,
        explanation: day == null
            ? 'Remove $mealType after asking which day.'
            : 'Remove $mealType from day ${day.group(1)}.',
      );
    } else if (activityName != null && text.contains('move') && day != null) {
      command = TripAiCommand(
        type: TripAiCommandType.moveStop,
        destinationId: destinationId,
        activityName: activityName,
        targetDayNumber: int.tryParse(day.group(1)!),
        explanation:
            'Move $activityName to day ${day.group(1)} and revalidate the schedule.',
      );
    } else if (activityName != null && replacementRequested) {
      command = TripAiCommand(
        type: TripAiCommandType.replaceStop,
        destinationId: destinationId,
        activityName: activityName,
        replacementPreference: replacementPreference,
        replacementCriterion: replacementCriterion,
        explanation:
            'Replace $activityName with the best available alternative and revalidate the schedule.',
      );
    } else if (removeNamed != null && mealType == null) {
      command = TripAiCommand(
        type: TripAiCommandType.removeStop,
        destinationId: destinationId,
        activityName: activityName ?? removeNamed.group(1)!.trim(),
        explanation:
            'Remove the closest matching stop and revalidate the schedule.',
      );
    } else if (activityName != null &&
        (text.contains('remove') || text.contains('delete'))) {
      command = TripAiCommand(
        type: TripAiCommandType.removeStop,
        destinationId: destinationId,
        activityName: activityName,
        explanation: 'Remove $activityName and revalidate the schedule.',
      );
    } else if (text.contains('relax') ||
        text.contains('calm') ||
        text.contains('less rushed') ||
        text.contains('too many stops') ||
        text.contains('slow down')) {
      command = TripAiCommand(
        type: TripAiCommandType.relaxDay,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        explanation: day == null
            ? 'Reduce lower-priority stops across the schedule.'
            : 'Reduce lower-priority stops on day ${day.group(1)}.',
      );
    } else if (text.contains('more food') || text.contains('add food')) {
      command = TripAiCommand(
        type: TripAiCommandType.addFood,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        mealType: mealType,
        explanation: 'Add available food stops and revalidate the schedule.',
      );
    } else if (mealType != null && text.contains('add')) {
      command = TripAiCommand(
        type: TripAiCommandType.addFood,
        destinationId: destinationId,
        dayNumber: day == null ? null : int.tryParse(day.group(1)!),
        mealType: mealType,
        explanation: day == null
            ? 'Add one $mealType stop and revalidate the schedule.'
            : 'Add one $mealType stop to day ${day.group(1)} and revalidate the schedule.',
      );
    } else if (removeMuseumsRequested) {
      command = TripAiCommand(
        type: TripAiCommandType.removeMuseums,
        destinationId: destinationId,
        explanation: 'Remove museum stops and revalidate the schedule.',
      );
    } else if (reduceWalkingRequested) {
      command = TripAiCommand(
        type: TripAiCommandType.reduceWalking,
        destinationId: destinationId,
        explanation: 'Recheck the route ordering for shorter travel.',
      );
    } else if (_costExplanationRequested(text)) {
      // The message is filled in by the caller, which is the only place that
      // holds the plan the numbers come from.
      command = TripAiCommand(
        type: TripAiCommandType.explainCost,
        destinationId: destinationId,
        explanation: 'Explain how the trip total is calculated.',
      );
    } else if (explainRequested) {
      command = TripAiCommand(
        type: TripAiCommandType.explain,
        destinationId: destinationId,
        explanation:
            'This itinerary is built from your preferences, destination budget, available places, meal requirements, and route proximity.',
      );
    } else {
      command = TripAiCommand(
        type: TripAiCommandType.unsupported,
        destinationId: destinationId,
        explanation:
            'I cannot safely apply that yet. Try changing the budget, relaxing a day, or naming an activity to remove, replace, or move.',
      );
    }
    return TripAiProposal(command: command, summary: command.reply);
  }

  /// Recognises "why is it that much" in the shapes people actually type.
  /// Deliberately narrow: a question about money and where it came from, not
  /// any mention of price.
  static bool _costExplanationRequested(String text) {
    const moneyWords = [
      'cost',
      'costs',
      'price',
      'prices',
      'total',
      'expense',
      'expenses',
      'budget',
      'spend',
      'spending',
      'expensive',
    ];
    const askWords = [
      'why',
      'how',
      'breakdown',
      'break down',
      'explain',
      'made up',
      'add up',
      'adds up',
      'come from',
      'comes from',
      'calculated',
      'what makes',
      'where does',
    ];

    final mentionsMoney = moneyWords.any(text.contains);
    if (!mentionsMoney) return false;

    // "change my budget to 900" is an edit, not a question.
    if (RegExp(r'[0-9]').hasMatch(text) &&
        RegExp(r'\b(under|to|set|change|reduce|increase|make)\b')
            .hasMatch(text)) {
      return false;
    }

    return askWords.any(text.contains);
  }

  int? _parseTimeMinutes(String text) {
    final match = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|h)?',
    ).allMatches(text).lastOrNull;
    if (match == null) return null;
    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final suffix = match.group(3);
    if (hour == null || minute > 59) return null;
    if (suffix == 'pm' && hour < 12) hour += 12;
    if (suffix == 'am' && hour == 12) hour = 0;
    if (hour > 23) return null;
    return hour * 60 + minute;
  }

  TripAiStopReference? _localStopReference(String raw, int? dayNumber) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final activity = RegExp(
      r'^activity\s+(\d+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (activity != null) {
      return TripAiStopReference(
        dayNumber: dayNumber,
        activityNumber: int.parse(activity.group(1)!),
      );
    }
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return TripAiStopReference(
        dayNumber: dayNumber,
        activityNumber: int.parse(value),
      );
    }
    final meal = const ['breakfast', 'lunch', 'dinner']
        .where((item) => item == value.toLowerCase())
        .firstOrNull;
    if (meal != null) {
      return TripAiStopReference(dayNumber: dayNumber, mealType: meal);
    }
    return TripAiStopReference(dayNumber: dayNumber, activityName: value);
  }
}
