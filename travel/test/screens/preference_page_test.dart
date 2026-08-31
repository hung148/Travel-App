import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';
import 'package:travel/views/preferences/preference_page.dart';

import 'preference_page_test.mocks.dart';

void main() {
  late MockPreferenceViewmodel viewModel;

  setUp(() {
    viewModel = MockPreferenceViewmodel();
    when(viewModel.isLoading).thenReturn(false);
    when(viewModel.errorMessage).thenReturn(null);
    when(viewModel.savedSuccessfully).thenReturn(false);
    when(viewModel.preference).thenReturn(null);
    when(viewModel.loadPreferences(any)).thenAnswer((_) async {});
    when(viewModel.addListener(any)).thenReturn(null);
    when(viewModel.removeListener(any)).thenReturn(null);
    when(viewModel.hasListeners).thenReturn(false);
  });

  Widget buildPage() => ChangeNotifierProvider<PreferenceViewmodel>.value(
    value: viewModel,
    child: const MaterialApp(home: PreferencePage(ownerId: 'user-1')),
  );

  testWidgets('renders the current first onboarding question', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pump();

    expect(find.text('What kind of experiences do you want?'), findsOneWidget);
    expect(find.text('Nature'), findsOneWidget);
    expect(find.text('Beach'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('enables continue after selecting an experience', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pump();
    await tester.tap(find.text('Nature'));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows a user-facing service error', (tester) async {
    when(viewModel.errorMessage).thenReturn('Unable to load preferences.');
    await tester.pumpWidget(buildPage());
    await tester.pump();

    expect(find.text('Unable to load preferences.'), findsOneWidget);
  });
}
