import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/account_deletion_service.dart';
import 'package:travel/service/auth_service.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';

class FakeAuthService extends Fake implements AuthService {
  final controller = StreamController<AppUser?>();
  final reload = Completer<void>();
  bool verified = false;
  int reloadCalls = 0;

  @override
  Stream<AppUser?> get authStateChanges => controller.stream;

  @override
  bool get isEmailVerified => verified;

  @override
  Future<void> reloadUser() {
    reloadCalls++;
    return reload.future;
  }
}

class FakeAccountDeletionService extends Fake
    implements AccountDeletionService {}

void main() {
  late FakeAuthService service;
  late AuthViewModel model;
  final savedUser = AppUser(
    uid: 'saved-user',
    name: 'Traveler',
    email: 'traveler@example.com',
    onboardingCompleted: true,
  );

  void initialize() {
    service = FakeAuthService();
    model = AuthViewModel(service, FakeAccountDeletionService());
  }

  tearDown(() async {
    model.dispose();
    await service.controller.close();
  });

  testWidgets('keeps startup loading until cached verification is refreshed', (
    tester,
  ) async {
    initialize();
    final visibleUnverifiedStates = <bool>[];
    model.addListener(() {
      visibleUnverifiedStates.add(
        !model.isRestoringSession &&
            model.user != null &&
            !model.isEmailVerified,
      );
    });
    service.controller.add(savedUser);
    await tester.pump();
    expect(model.isRestoringSession, isTrue);
    expect(service.reloadCalls, 1);

    service.verified = true;
    service.reload.complete();
    await tester.pump();

    expect(model.isRestoringSession, isFalse);
    expect(model.user, savedUser);
    expect(model.isEmailVerified, isTrue);
    expect(model.isNewUser, isFalse);
    expect(visibleUnverifiedStates, isNot(contains(true)));
  });

  testWidgets('still requires verification for an unverified account', (
    tester,
  ) async {
    initialize();
    service.controller.add(savedUser);
    await tester.pump();
    service.reload.complete();
    await tester.pump();
    expect(model.isRestoringSession, isFalse);
    expect(model.user, savedUser);
    expect(model.isEmailVerified, isFalse);
  });

  testWidgets('already verified sessions do not wait for a network refresh', (
    tester,
  ) async {
    initialize();
    service.verified = true;
    service.controller.add(savedUser);
    await tester.pump();
    expect(model.isRestoringSession, isFalse);
    expect(model.isEmailVerified, isTrue);
    expect(service.reloadCalls, 0);
  });

  testWidgets('signed out startup does not refresh verification', (
    tester,
  ) async {
    initialize();
    service.controller.add(null);
    await tester.pump();
    expect(model.isRestoringSession, isFalse);
    expect(model.user, isNull);
    expect(service.reloadCalls, 0);
  });

  testWidgets('a stalled refresh does not leave startup loading forever', (
    tester,
  ) async {
    initialize();
    service.controller.add(savedUser);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(model.isRestoringSession, isFalse);
    expect(model.isEmailVerified, isFalse);
    service.reload.complete();
    await tester.pump();
  });
}
