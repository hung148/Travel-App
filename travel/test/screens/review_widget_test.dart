import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel/views/summary/review_widget.dart';

void main() {
  Future<void> showReview(
    WidgetTester tester,
    Future<void> Function(int, String, String)? onSubmit,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ReviewWidget(onSubmit: onSubmit)),
      ),
    ),
  );

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Submit feedback');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('unsaved trips cannot submit feedback', (tester) async {
    await showReview(tester, null);
    await tester.tap(find.byType(IconButton).at(3));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('Save your trip'), findsOneWidget);
  });

  testWidgets('sends selected feedback and waits for persistence', (
    tester,
  ) async {
    final saved = Completer<void>();
    final requests = <List<Object>>[];
    await showReview(tester, (rating, best, worst) {
      requests.add([rating, best, worst]);
      return saved.future;
    });
    await tester.tap(find.byType(IconButton).at(3));
    await tester.tap(find.widgetWithText(FilterChip, 'Activities'));
    await tester.tap(find.widgetWithText(FilterChip, 'Too busy'));
    await tester.pump();
    await submit(tester);

    expect(requests, [
      [4, 'Activities', 'Too busy'],
    ]);
    expect(find.text('Feedback saved.'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    saved.complete();
    await tester.pump();
    expect(find.text('Feedback saved.'), findsOneWidget);
  });

  testWidgets('failed writes show an error and allow retry', (tester) async {
    var attempts = 0;
    await showReview(tester, (rating, best, worst) async {
      attempts++;
      if (attempts == 1) throw Exception('permission-denied');
    });
    await tester.tap(find.byType(IconButton).at(4));
    await tester.pump();
    await submit(tester);
    expect(find.text('Feedback saved.'), findsNothing);
    expect(
      find.text('Could not save feedback. Please try again.'),
      findsOneWidget,
    );
    await submit(tester);
    expect(attempts, 2);
    expect(find.text('Feedback saved.'), findsOneWidget);
  });
}
