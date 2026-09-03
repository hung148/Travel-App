import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel/models/ai/trip_ai_command.dart';
import 'package:travel/service/ai/trip_ai_service.dart';

void main() {
  test('parses a strict structured command', () {
    final command = TripAiCommand.fromJson({
      'command': 'relax_day',
      'destinationId': 'hue',
      'arguments': {'dayNumber': 2, 'budget': null, 'style': null},
      'explanation': 'Relax day 2.',
    });

    expect(command.type, TripAiCommandType.relaxDay);
    expect(command.destinationId, 'hue');
    expect(command.dayNumber, 2);
    expect(command.changesTrip, isTrue);
  });

  test('local fallback creates a destination-scoped budget proposal', () async {
    final service = TripAiService(endpoint: '');

    final proposal = await service.propose(
      instruction: 'Keep it under \$900',
      context: {'destinationId': 'danang'},
    );

    expect(proposal.command.type, TripAiCommandType.changeBudget);
    expect(proposal.command.destinationId, 'danang');
    expect(proposal.command.budget, 900);
  });

  test('unsupported local requests never mutate a trip', () async {
    final service = TripAiService(endpoint: '');

    final proposal = await service.propose(
      instruction: 'Book everything for me',
      context: {'destinationId': 'hue'},
    );

    expect(proposal.command.type, TripAiCommandType.unsupported);
    expect(proposal.command.changesTrip, isFalse);
  });

  test('local fallback recognizes a named stop move', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'Move Imperial City to day 2',
      context: {
        'destinationId': 'hue',
        'days': [
          {
            'dayNumber': 1,
            'places': ['Imperial City', 'Dong Ba Market'],
          },
          {'dayNumber': 2, 'places': <String>[]},
        ],
      },
    );

    expect(proposal.command.type, TripAiCommandType.moveStop);
    expect(proposal.command.activityName, 'Imperial City');
    expect(proposal.command.targetDayNumber, 2);
  });

  test('local fallback targets one requested meal and day', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'Add breakfast to day 1',
      context: {'destinationId': 'hue', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.addFood);
    expect(proposal.command.dayNumber, 1);
    expect(proposal.command.mealType, 'breakfast');
  });

  test('local fallback asks the page to resolve a meal day', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'Remove breakfast',
      context: {'destinationId': 'hue', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.removeStop);
    expect(proposal.command.mealType, 'breakfast');
    expect(proposal.command.dayNumber, isNull);
  });

  test('local fallback parses numbered activities on one day', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'Remove activities 3 and 4 from day 1',
      context: {'destinationId': 'hue', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.removeStop);
    expect(proposal.command.dayNumber, 1);
    expect(proposal.command.activityNumbers, [3, 4]);
  });

  test('local fallback understands a better meal replacement', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'Change breakfast on day 2 to a better place',
      context: {'destinationId': 'hue', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.replaceStop);
    expect(proposal.command.mealType, 'breakfast');
    expect(proposal.command.dayNumber, 2);
    expect(proposal.command.replacementCriterion, 'best_match');
  });

  test('local fallback parses a day start time', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'Start day 2 at 9 AM',
      context: {'destinationId': 'hue', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.setDayStartTime);
    expect(proposal.command.dayNumber, 2);
    expect(proposal.command.startMinutes, 9 * 60);
  });

  test('local fallback parses an exact stop count', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'Add 2 activities to day 1',
      context: {'destinationId': 'hue', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.addStops);
    expect(proposal.command.dayNumber, 1);
    expect(proposal.command.stopCount, 2);
  });

  test(
    'remote gateway receives auth and returns a structured proposal',
    () async {
      final service = TripAiService(
        endpoint: 'http://127.0.0.1:8787/interpretTripRequest',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer firebase-token');
          return http.Response(
            '{"command":"add_food","destinationId":"hue",'
            '"arguments":{"dayNumber":null,"budget":null,"style":null},'
            '"explanation":"Add food stops."}',
            200,
          );
        }),
      );

      final proposal = await service.propose(
        instruction: 'Could you enhance the culinary dimension?',
        context: {'destinationId': 'hue'},
        idToken: 'firebase-token',
      );

      expect(proposal.command.type, TripAiCommandType.addFood);
      expect(proposal.command.destinationId, 'hue');
    },
  );

  test('falls back safely when the provider rate limits a request', () async {
    final service = TripAiService(
      endpoint: 'http://127.0.0.1:8787/interpretTripRequest',
      client: MockClient((_) async => http.Response('{}', 429)),
    );

    final proposal = await service.propose(
      instruction: 'Could you enhance the culinary dimension?',
      context: {'destinationId': 'hue'},
    );
    expect(proposal.command.type, TripAiCommandType.unsupported);
  });

  test(
    'local fallback handles partial stop names and budget wording',
    () async {
      final service = TripAiService(endpoint: '');
      final context = {'destinationId': 'danang', 'days': <Object>[]};

      final move = await service.propose(
        instruction: 'Move KDL to day 1',
        context: context,
      );
      final remove = await service.propose(
        instruction: 'Remove Cong Vien',
        context: context,
      );
      final budget = await service.propose(
        instruction: 'Change the budget to \$900',
        context: context,
      );

      expect(move.command.activityName, 'kdl');
      expect(move.command.targetDayNumber, 1);
      expect(remove.command.activityName, 'cong vien');
      expect(budget.command.budget, 900);
    },
  );

  test('local fallback handles closer meals and an existing style', () async {
    final service = TripAiService(endpoint: '');
    final context = {'destinationId': 'danang', 'days': <Object>[]};

    final meal = await service.propose(
      instruction: 'Find a closer breakfast for day 1',
      context: context,
    );
    final style = await service.propose(
      instruction: 'Use Explorer style',
      context: context,
    );

    expect(meal.command.type, TripAiCommandType.replaceStop);
    expect(meal.command.mealType, 'breakfast');
    expect(meal.command.dayNumber, 1);
    expect(meal.command.replacementCriterion, 'closer');
    expect(style.command.type, TripAiCommandType.changeStyle);
    expect(style.command.style, 'Explorer');
  });

  test('local fallback accepts natural closer-breakfast wording', () async {
    final service = TripAiService(endpoint: '');

    final proposal = await service.propose(
      instruction: 'find me closer breakfast place for day 1',
      context: {'destinationId': 'danang', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.replaceStop);
    expect(proposal.command.mealType, 'breakfast');
    expect(proposal.command.dayNumber, 1);
    expect(proposal.command.replacementCriterion, 'closer');
  });

  test(
    'local fallback handles swap, scheduled replacement, and positioning',
    () async {
      final service = TripAiService(endpoint: '');
      final context = {'destinationId': 'hue', 'days': <Object>[]};

      final swap = await service.propose(
        instruction: 'Swap activity 1 on day 1 with lunch on day 2',
        context: context,
      );
      final replace = await service.propose(
        instruction: 'Replace activity 1 on day 1 with Museum from day 2',
        context: context,
      );
      final relative = await service.propose(
        instruction: 'Move Museum before Walking Street',
        context: context,
      );
      final timed = await service.propose(
        instruction: 'Move Imperial City to 2 PM on day 2',
        context: context,
      );

      expect(swap.command.type, TripAiCommandType.swapStops);
      expect(replace.command.type, TripAiCommandType.replaceWithScheduledStop);
      expect(relative.command.type, TripAiCommandType.moveStopRelative);
      expect(relative.command.relativePosition, 'before');
      expect(timed.command.type, TripAiCommandType.moveStopTime);
      expect(timed.command.startMinutes, 14 * 60);
      expect(timed.command.targetDayNumber, 2);
    },
  );

  test('local fallback swaps numbered activities across days', () async {
    final service = TripAiService(endpoint: '');
    final proposal = await service.propose(
      instruction: 'swap activity 3 in day 1 with activity 7 in day 2',
      context: {'destinationId': 'hue', 'days': <Object>[]},
    );

    expect(proposal.command.type, TripAiCommandType.swapStops);
    expect(proposal.command.sourceStop?.dayNumber, 1);
    expect(proposal.command.sourceStop?.activityNumber, 3);
    expect(proposal.command.targetStop?.dayNumber, 2);
    expect(proposal.command.targetStop?.activityNumber, 7);
  });

  test('local fallback swaps named stops and supports numbered exact-time moves', () async {
    final service = TripAiService(endpoint: '');
    final context = {'destinationId': 'hue', 'days': <Object>[]};

    final swap = await service.propose(
      instruction: 'swap Museum in day 1 with Walking Street in day 3',
      context: context,
    );
    final timed = await service.propose(
      instruction: 'move activity 4 to 3 PM on day 2',
      context: context,
    );

    expect(swap.command.type, TripAiCommandType.swapStops);
    expect(swap.command.sourceStop?.activityName, 'museum');
    expect(swap.command.sourceStop?.dayNumber, 1);
    expect(swap.command.targetStop?.activityName, 'walking street');
    expect(swap.command.targetStop?.dayNumber, 3);
    expect(timed.command.type, TripAiCommandType.moveStopTime);
    expect(timed.command.sourceStop?.activityNumber, 4);
    expect(timed.command.targetDayNumber, 2);
    expect(timed.command.startMinutes, 15 * 60);
  });
}
