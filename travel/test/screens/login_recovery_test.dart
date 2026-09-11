import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travel/models/user.dart';
import 'package:travel/service/auth_service.dart';
import 'package:travel/service/account_deletion_service.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';
import 'package:travel/views/auth/login.dart';

class FailedAuth extends Fake implements AuthService {
  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();
  @override
  Future<AppUser> login({required String email, required String password}) async {
    throw Exception('Invalid email or password.');
  }
}
class UnusedDeletion extends Fake implements AccountDeletionService {}

void main() {
  testWidgets('failed login allows editing both fields without a clear button', (tester) async {
    final model = AuthViewModel(FailedAuth(), UnusedDeletion())..isLoading = false;
    addTearDown(model.dispose);
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: model,
      child: const MaterialApp(home: LoginPage())));
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), 'fictional-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(model.isLoading, false);
    expect(find.byTooltip('Clear password'), findsNothing);
    await tester.tap(fields.at(0));
    await tester.pumpAndSettle();
    final emailEditable = tester.widget<EditableText>(find.descendant(
      of: fields.at(0), matching: find.byType(EditableText)));
    expect(emailEditable.focusNode.hasFocus, true);
    await tester.enterText(fields.at(0), 'corrected@example.com');
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, 'corrected@example.com');
    await tester.tap(fields.at(1));
    await tester.enterText(fields.at(1), '');
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(fields.at(1));
    expect(field.controller!.text, isEmpty);
    final editable = tester.widget<EditableText>(find.descendant(
      of: fields.at(1), matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, true);
    await tester.enterText(fields.at(1), 'replacement');
    expect(field.controller!.text, 'replacement');
    expect(tester.takeException(), isNull);
  });
}
