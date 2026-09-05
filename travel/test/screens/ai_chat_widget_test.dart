import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/ai/trip_ai_command.dart';
import 'package:travel/views/plan_trip/ai_chat_widget.dart';

void main() {
  testWidgets('previews a command and applies it only after confirmation', (
    tester,
  ) async {
    var applied = false;
    const command = TripAiCommand(
      type: TripAiCommandType.relaxDay,
      destinationId: 'hue',
      dayNumber: 2,
      explanation: 'Reduce lower-priority stops on day 2.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: AiChatWidget(
              onPropose: (_, __) async => const TripAiProposal(
                command: command,
                summary: 'Reduce lower-priority stops on day 2.',
              ),
              onApply: (_) async {
                applied = true;
                return 'Change applied and validated.';
              },
              liveAiEnabled: true,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Ask AI to adjust your trip...'),
      'Relax day 2',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(applied, isFalse);
    expect(find.text('Apply change'), findsOneWidget);

    await tester.tap(find.text('Apply change'));
    await tester.pumpAndSettle();
    expect(applied, isTrue);
    expect(find.text('Change applied and validated.'), findsOneWidget);
  });

  testWidgets('offers one undo after an applied AI change', (tester) async {
    var undoCount = 0;
    const command = TripAiCommand(
      type: TripAiCommandType.relaxDay,
      destinationId: 'hue',
      dayNumber: 2,
      explanation: 'Reduce lower-priority stops on day 2.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: AiChatWidget(
              onPropose: (_, __) async => const TripAiProposal(
                command: command,
                summary: 'Reduce lower-priority stops on day 2.',
              ),
              onApply: (_) async => 'Change applied and validated.',
              onUndo: () async {
                undoCount++;
                return 'Restored the plan from before the last AI change.';
              },
              canUndo: () => true,
              liveAiEnabled: true,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Ask AI to adjust your trip...'),
      'Relax day 2',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply change'));
    await tester.pumpAndSettle();

    expect(find.text('Undo AI change'), findsOneWidget);
    await tester.tap(find.text('Undo AI change'));
    await tester.pumpAndSettle();

    expect(undoCount, 1);
    expect(
      find.text('Restored the plan from before the last AI change.'),
      findsOneWidget,
    );
    expect(find.text('Undo AI change'), findsNothing);
  });
}
