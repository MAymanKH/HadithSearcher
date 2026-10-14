import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/core/constants/routes.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/views/similar_hadith/similar_hadith_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry/fake_backend.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  for (final brightness in Brightness.values) {
    testWidgets('system icons follow the ${brightness.name} app theme', (
      tester,
    ) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      await preferences.setString('theme', brightness.name);
      final telemetry = TelemetryService(
        preferences: preferences,
        backend: FakeBackend(),
      );
      addTearDown(telemetry.dispose);
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 24);
      tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        HadithSearcherApp(
          initialThemeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();

      void expectOverlay() {
        final style = SystemChrome.latestStyle!;
        final icons = brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        expect(style.statusBarIconBrightness, icons);
        expect(style.systemNavigationBarIconBrightness, icons);
        expect(style.statusBarColor, isNull);
        expect(style.systemNavigationBarColor, isNull);
        expect(style.systemNavigationBarDividerColor, isNull);
      }

      expectOverlay();
      await telemetry.save(diagnostics: false, analytics: false);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expectOverlay();
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'landscape cutouts leave search and navigation controls reachable',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      final telemetry = TelemetryService(
        preferences: preferences,
        backend: FakeBackend(),
      );
      await telemetry.save(diagnostics: false, analytics: false);
      addTearDown(telemetry.dispose);
      tester.view.physicalSize = const Size(850, 400);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(
        left: 48,
        right: 24,
        bottom: 24,
      );
      tester.view.padding = const FakeViewPadding(
        left: 48,
        right: 24,
        bottom: 24,
      );
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        HadithSearcherApp(
          initialThemeMode: ThemeMode.light,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();
      final search = tester.getRect(find.byType(TextField));
      expect(search.left, greaterThanOrEqualTo(48));
      expect(search.right, lessThanOrEqualTo(826));
      final navigation = tester.getRect(find.byType(NavigationBar));
      expect(navigation.left, greaterThanOrEqualTo(48));
      expect(navigation.right, lessThanOrEqualTo(826));
      // The background reaches the edge; only the destinations need bottom padding.
      expect(navigation.bottom, 400);
      for (final destination in find.byType(NavigationDestination).evaluate()) {
        final bounds = tester.getRect(find.byWidget(destination.widget));
        expect(bounds.bottom, lessThanOrEqualTo(376));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('similar hadith content stays above three-button navigation', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final telemetry = TelemetryService(
      preferences: preferences,
      backend: FakeBackend(),
    );
    await telemetry.save(diagnostics: false, analytics: false);
    addTearDown(telemetry.dispose);
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 48);
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      HadithSearcherApp(
        initialThemeMode: ThemeMode.light,
        telemetry: telemetry,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(TextField));
    Navigator.of(context).pushNamed(similarHadithRoute);
    await tester.pumpAndSettle();
    final emptyState = find
        .descendant(
          of: find.byType(SimilarHadithView),
          matching: find.byType(Center),
        )
        .first;
    expect(tester.getRect(emptyState).bottom, lessThanOrEqualTo(802));
    expect(tester.getRect(find.byType(AppBar)).top, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
