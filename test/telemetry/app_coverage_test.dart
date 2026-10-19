import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/services/settings_service.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/services/update_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/welcome/welcome_view.dart';
import 'package:hadithsearcher/widgets/hadith_reading_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TelemetryService telemetry;
  late FakeBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    telemetry = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: backend,
    );
    TelemetryService.instance = telemetry;
    await telemetry.save(diagnostics: true, analytics: true);
  });

  tearDown(() {
    TelemetryService.instance = null;
    telemetry.dispose();
  });

  test(
    'settings fallback reports its failure and still returns defaults',
    () async {
      await telemetry.preferences.setInt('theme', 42);
      final settings = await SettingsService().getSettings();
      expect(settings.themeMode, ThemeMode.system);
      expect(backend.reports, ['settings.getSettings']);
    },
  );

  test('update failures are reported without blocking app use', () async {
    final updates = UpdateService(
      channel: UpdateChannel.play,
      packageInfo: () async => PackageInfo(
        appName: 'Hadith Searcher',
        packageName: UpdateService.packageName,
        version: '1.0.0',
        buildNumber: '1',
      ),
      playVersion: () async => throw StateError('Store unavailable'),
    );
    addTearDown(updates.dispose);
    expect(await updates.check(), isEmpty);
    expect(updates.failed, true);
    expect(backend.reports, ['updates.play.check']);
  });

  test('language changes are captured only after a successful save', () async {
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    await settings.setLanguage('en');
    expect(backend.events, ['language_changed']);
    expect(backend.properties.single, {'language': 'en'});
    await telemetry.save(diagnostics: false, analytics: false);
    await settings.setLanguage('ar');
    expect(backend.events, ['language_changed']);
  });

  testWidgets('offline explanation views are tracked without an API call', (
    tester,
  ) async {
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showExplanationSheet(
                  context,
                  load: () async => ApiResult.success('Saved explanation'),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Saved explanation'), findsOneWidget);
    expect(backend.events, ['explanation_opened']);
  });

  testWidgets('welcome screen respects the current analytics choice', (
    tester,
  ) async {
    final settings = SettingsViewModel();
    addTearDown(settings.dispose);
    Future<void> mount(Key key) => tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WelcomeView(key: key),
        ),
      ),
    );
    await mount(const ValueKey('enabled'));
    expect(backend.events, ['screen_viewed']);
    expect(backend.properties.single, {'screen': 'welcome'});
    await telemetry.save(diagnostics: false, analytics: false);
    await mount(const ValueKey('disabled'));
    expect(backend.events, ['screen_viewed']);
  });
}
