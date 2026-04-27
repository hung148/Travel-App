import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:travel/models/preference/preferences.dart';
import 'package:travel/views/preferences/preference_page.dart';
import 'package:travel/viewmodels/preference_viewmodel.dart';

import 'preference_page_test.mocks.dart';

@GenerateMocks([PreferenceViewmodel])
void main() {
  late MockPreferenceViewmodel mockVm;

  setUp(() {
    mockVm = MockPreferenceViewmodel();

    // Default stubs every test needs
    when(mockVm.isLoading).thenReturn(false);
    when(mockVm.errorMessage).thenReturn(null);
    when(mockVm.savedSuccessfully).thenReturn(false);
    when(mockVm.preference).thenReturn(null);
    when(mockVm.loadPreferences(any)).thenAnswer((_) async {});
    when(mockVm.savePreferences(any)).thenAnswer((_) async {});

    // Required by ChangeNotifier internals
    when(mockVm.addListener(any)).thenReturn(null);
    when(mockVm.removeListener(any)).thenReturn(null);
    when(mockVm.hasListeners).thenReturn(false);
  });

  // Helper to build the widget under test
  Widget buildPage() {
    return ChangeNotifierProvider<PreferenceViewmodel>.value(
      value: mockVm,
      child: const MaterialApp(
        home: PreferencePage(ownerId: 'user-123'),
      ),
    );
  }

  // Helper to make a test preference
  Preference makePreference({
    List<String> experienceType = const ['Nature', 'food'],
    String activityLevel = 'Relaxed',
    String spendingStyle = 'Budget',
  }) {
    return Preference(
      id: 'pref-1',
      ownerId: 'user-123',
      experienceType: experienceType,
      activityLevel: activityLevel,
      spendingStyle: spendingStyle,
      interests: [],
    );
  }

  group('renders correctly', () {
    testWidgets('shows all section labels', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('What do you enjoy?'), findsOneWidget);
      expect(find.text('Trip pace'), findsOneWidget);
      expect(find.text('Budget preference'), findsOneWidget);
    });

    testWidgets('shows all chips', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      for (final label in [
        'Nature', 'History', 'Food', 'Mix',
        'Relaxed', 'Moderate', 'Very Active',
        'Budget', 'Normal', 'Luxury',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label chip missing');
      }
    });

    testWidgets('save button is disabled when nothing selected', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      final btn = tester.widget<FilledButton>(find.byKey(const Key('save_button')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows loading spinner when isLoading is true', (tester) async {
      when(mockVm.isLoading).thenReturn(true);

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when errorMessage is set', (tester) async {
      when(mockVm.errorMessage).thenReturn('Something went wrong');

      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  group('chip selection', () {
    testWidgets('save button enables after all three selections', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      await tester.tap(find.byKey(const Key('chip_Nature')));
      await tester.tap(find.byKey(const Key('chip_Relaxed')));
      await tester.tap(find.byKey(const Key('chip_Budget')));
      await tester.pump();

      final btn = tester.widget<FilledButton>(find.byKey(const Key('save_button')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('only one chip selected per section', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Tap Nature then tap History — only History should be selected
      await tester.tap(find.byKey(const Key('chip_Nature')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chip_History')));
      await tester.pump();

      final natureChip = tester.widget<ChoiceChip>(find.byKey(const Key('chip_Nature')));
      final historyChip = tester.widget<ChoiceChip>(find.byKey(const Key('chip_History')));

      expect(natureChip.selected, false);
      expect(historyChip.selected, true);
    });
  });

  group('saving', () {
    testWidgets('calls savePreferences with correct field values', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      await tester.tap(find.byKey(const Key('chip_Food')));
      await tester.tap(find.byKey(const Key('chip_Moderate')));
      await tester.tap(find.byKey(const Key('chip_Luxury')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pump();

      final captured =
          verify(mockVm.savePreferences(captureAny)).captured.first as Preference;

      expect(captured.experienceType, 'Food');
      expect(captured.activityLevel, 'Moderate');
      expect(captured.spendingStyle, 'Luxury');
      expect(captured.ownerId, 'user-123');
    });
  });

  group('pre-population', () {
    testWidgets('pre-selects chips when existing preference is loaded',
        (tester) async {
      when(mockVm.preference).thenReturn(makePreference(
        experienceType: ['History', 'relax'],
        activityLevel: 'Very Active',
        spendingStyle: 'Normal',
      ));

      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump(); // second pump for addPostFrameCallback

      final historyChip =
          tester.widget<ChoiceChip>(find.byKey(const Key('chip_History')));
      final activeChip =
          tester.widget<ChoiceChip>(find.byKey(const Key('chip_Very Active')));
      final normalChip =
          tester.widget<ChoiceChip>(find.byKey(const Key('chip_Normal')));

      expect(historyChip.selected, true);
      expect(activeChip.selected, true);
      expect(normalChip.selected, true);
    });
  });
}