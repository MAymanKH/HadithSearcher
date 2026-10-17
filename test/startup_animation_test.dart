import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/views/main_shell.dart';
import 'package:hadithsearcher/views/privacy/telemetry_consent_view.dart';
import 'package:hadithsearcher/views/welcome/welcome_view.dart';

import 'telemetry/fake_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, TelemetryPolicy policy) async {
    final telemetry = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: FakeBackend(),
      policy: policy,
    );
    addTearDown(telemetry.dispose);
    await tester.pumpWidget(
      HadithSearcherApp(
        initialThemeMode: ThemeMode.light,
        telemetry: telemetry,
      ),
    );
  }

  Future<void> waitFor(WidgetTester tester, Type page) async {
    for (
      var frame = 0;
      frame < 10 && find.byType(page).evaluate().isEmpty;
      frame++
    ) {
      await tester.pump();
    }
    expect(find.byType(page), findsOneWidget);
  }

  double pageOpacity(WidgetTester tester, Type page) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(page),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  double iconOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byKey(const ValueKey('search-placeholder-fade')),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  double textOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .ancestor(
              of: find.text('ابحث عن حديث'),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  Future<void> expectTransition(WidgetTester tester, Type from, Type to) async {
    await waitFor(tester, to);
    expect(find.byType(from), findsOneWidget);
    expect(pageOpacity(tester, to), 0);
    final outgoing = find.ancestor(
      of: find.byType(from),
      matching: find.byType(IgnorePointer),
    );
    expect(
      outgoing.evaluate().any(
        (element) => (element.widget as IgnorePointer).ignoring,
      ),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(pageOpacity(tester, to), inExclusiveRange(0, 1));
    expect(pageOpacity(tester, from), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.byType(from), findsNothing);
    expect(pageOpacity(tester, to), 1);
  }

  for (final policy in TelemetryPolicy.values) {
    testWidgets('cold launch animates from the logo to search for $policy', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'welcomeCompleted': true,
        TelemetryService.consentKey: const TelemetryConsent(
          decided: true,
        ).encode(),
      });
      await mount(tester, policy);
      expect(find.byKey(const ValueKey('startup-splash')), findsOneWidget);
      await waitFor(tester, MainShell);
      expect(pageOpacity(tester, MainShell), 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(pageOpacity(tester, MainShell), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('startup-splash')), findsNothing);
      expect(pageOpacity(tester, MainShell), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('startup pages animate for $policy', (tester) async {
      await mount(tester, policy);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('complete-welcome')));
      await tester.tap(find.byKey(const Key('complete-welcome')));
      final next = policy == TelemetryPolicy.optIn
          ? TelemetryConsentView
          : MainShell;
      await expectTransition(tester, WelcomeView, next);
      if (policy == TelemetryPolicy.optIn) {
        await tester.ensureVisible(
          find.byKey(const Key('save-telemetry-consent')),
        );
        await tester.tap(find.byKey(const Key('save-telemetry-consent')));
        await expectTransition(tester, TelemetryConsentView, MainShell);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'search icon and text fade together without restarting on rebuild',
    (tester) async {
      SharedPreferences.setMockInitialValues({'welcomeCompleted': true});
      await mount(tester, TelemetryPolicy.alwaysOn);
      await waitFor(tester, MainShell);
      expect(iconOpacity(tester), 0);
      expect(textOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 350));
      final midway = iconOpacity(tester);
      expect(midway, inExclusiveRange(0, 1));
      expect(textOpacity(tester), midway);
      final search = tester
          .element(find.byType(MainShell))
          .read<SearchViewModel>();
      await search.setShowActiveFilters(false);
      await tester.pump();
      expect(iconOpacity(tester), midway);
      await tester.pumpAndSettle();
      expect(iconOpacity(tester), 1);
      expect(textOpacity(tester), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion skips startup transitions and the icon fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await mount(tester, TelemetryPolicy.optIn);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('complete-welcome')));
    await tester.tap(find.byKey(const Key('complete-welcome')));
    await waitFor(tester, TelemetryConsentView);
    await tester.pump();
    expect(find.byType(WelcomeView), findsNothing);
    expect(pageOpacity(tester, TelemetryConsentView), 1);
    await tester.ensureVisible(find.byKey(const Key('save-telemetry-consent')));
    await tester.tap(find.byKey(const Key('save-telemetry-consent')));
    await waitFor(tester, MainShell);
    await tester.pump();
    expect(find.byType(TelemetryConsentView), findsNothing);
    expect(pageOpacity(tester, MainShell), 1);
    expect(iconOpacity(tester), 1);
    expect(textOpacity(tester), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
