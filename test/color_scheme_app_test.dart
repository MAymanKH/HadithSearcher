import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/startup_flow.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/search_catalogs.dart';
import 'telemetry/fake_backend.dart';

void main() {
  testWidgets(
    'saved palette is used on the first frame and follows system brightness',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'theme': 'system',
        'colorScheme': 'sepia',
        'language': 'en',
      });
      await seedCatalogCache();
      final telemetry = TelemetryService(
        preferences: await SharedPreferences.getInstance(),
        backend: FakeBackend(),
      );
      addTearDown(telemetry.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        HadithSearcherApp(
          initialThemeMode: ThemeMode.system,
          initialColorScheme: ColorSchemePreference.sepia,
          telemetry: telemetry,
        ),
      );
      // Inspect the first frame before the asynchronous settings load settles.
      ColorScheme current() =>
          Theme.of(tester.element(find.byType(StartupFlow))).colorScheme;
      expect(
        current(),
        AppTheme.build(
          ColorSchemePreference.sepia,
          Brightness.dark,
        ).colorScheme,
      );
      await finishCatalogPreload(
        tester,
        tester
            .element(find.byType(MaterialApp))
            .read<SearchViewModel>()
            .preloadCatalogs(),
      );
      await tester.pumpAndSettle();
      expect(current().brightness, Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        current(),
        AppTheme.build(
          ColorSchemePreference.sepia,
          Brightness.light,
        ).colorScheme,
      );
      final settings = tester
          .element(find.byType(MaterialApp))
          .read<SettingsViewModel>();
      expect(settings.settings.theme, ThemePreference.system);
      expect(settings.settings.colorScheme, ColorSchemePreference.sepia);

      await tester.tap(find.byKey(const Key('color-scheme-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forest').last);
      await tester.pumpAndSettle();
      expect(
        current(),
        AppTheme.build(
          ColorSchemePreference.forest,
          Brightness.light,
        ).colorScheme,
      );
      expect(settings.settings.theme, ThemePreference.system);
      expect(
        (await SharedPreferences.getInstance()).getString('colorScheme'),
        'forest',
      );

      await tester.tap(find.byKey(const Key('theme-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(
        current(),
        AppTheme.build(
          ColorSchemePreference.forest,
          Brightness.dark,
        ).colorScheme,
      );
      expect(settings.settings.colorScheme, ColorSchemePreference.forest);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
