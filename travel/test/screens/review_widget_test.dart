import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel/models/feedback.dart' as model;
import 'package:travel/models/trip/trip.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/feedback_service.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/views/summary/review_widget.dart';

class TestAuth extends ChangeNotifier implements AuthViewModel {
  @override
  AppUser get user =>
      AppUser(uid: 'user', name: 'Traveler', email: 'user@example.com');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFeedbackService extends Fake implements FeedbackService {
  TestFeedbackService(this.save);
  final Future<void> Function(model.Feedback) save;
  @override
  Future<void> saveFeedback({required model.Feedback feedback}) =>
      save(feedback);
}

void main() {
  Future<void> showReview(
    WidgetTester tester,
    Future<void> Function(model.Feedback)? save,
  ) async {
    final auth = TestAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReviewWidget(
                trip: save == null
                    ? null
                    : Trip(
                        id: 'trip',
                        ownerId: 'user',
                        destination: 'Da Nang',
                        budget: 1000,
                        days: 2,
                        status: 'confirmed',
                      ),
                feedbackService: save == null
                    ? null
                    : TestFeedbackService(save),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> submitPrivately(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Submit feedback');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Keep private'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
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

  testWidgets(
    'persists feedback only after choosing private and waits for the write',
    (tester) async {
      final saved = Completer<void>();
      final requests = <model.Feedback>[];
      await showReview(tester, (feedback) {
        requests.add(feedback);
        return saved.future;
      });
      await tester.tap(find.byType(IconButton).at(3));
      await tester.tap(find.widgetWithText(FilterChip, 'Activities'));
      await tester.tap(find.widgetWithText(FilterChip, 'Too busy'));
      await tester.enterText(find.byType(TextField), 'A lovely trip.');
      final button = find.widgetWithText(FilledButton, 'Submit feedback');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, isEmpty);
      await tester.tap(find.text('Keep private'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, hasLength(1));
      expect(requests.single.id, 'trip_user');
      expect(requests.single.rating, 4);
      expect(requests.single.best, 'Liked: Activities\nA lovely trip.');
      expect(requests.single.worst, 'Too busy');
      expect(find.text('Private feedback saved.'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      saved.complete();
      await tester.pumpAndSettle();
      expect(find.text('Private feedback saved.'), findsOneWidget);
    },
  );

  testWidgets('failed writes show an error and retry uses the same document', (
    tester,
  ) async {
    final ids = <String>[];
    await showReview(tester, (feedback) async {
      ids.add(feedback.id);
      if (ids.length == 1) throw Exception('permission-denied');
    });
    await tester.tap(find.byType(IconButton).at(4));
    await tester.enterText(find.byType(TextField), 'A lovely trip.');
    await submitPrivately(tester);
    expect(
      find.text('Could not save feedback. Please try again.'),
      findsOneWidget,
    );
    await submitPrivately(tester);
    expect(ids, ['trip_user', 'trip_user']);
    expect(find.text('Private feedback saved.'), findsOneWidget);
  });
}
