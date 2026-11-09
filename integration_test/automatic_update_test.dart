import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/services/settings_service.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/services/update_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/settings/settings_view.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/telemetry/fake_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('update preference fits both languages and themes', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsViewModel();
    final telemetry = TelemetryService(
      preferences: preferences,
      backend: FakeBackend(),
    );
    if (const bool.fromEnvironment('UPDATE_SCREENSHOTS')) {
      await binding.convertFlutterSurfaceToImage();
    }
    for (final locale in ['en', 'ar']) {
      await settings.setLanguage(locale);
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await settings.setAutomaticUpdateChecks(true);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: telemetry),
            ],
            child: MaterialApp(
              theme: theme,
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsView(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byType(SwitchListTile);
        await tester.scrollUntilVisible(
          toggle,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(settings.settings.automaticUpdateChecks, isFalse);
        expect(
          (await SettingsService().getSettings()).automaticUpdateChecks,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('UPDATE_SCREENSHOTS')) {
          await binding.takeScreenshot(
            'settings-updates-$locale-${theme.brightness.name}',
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
    telemetry.dispose();
  });

  testWidgets('disabled automatic checks stay silent across service restarts', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final hosts = <String>[];
    server.listen((request) async {
      requests++;
      request.response.statusCode = 404;
      await request.response.close();
    });
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getBool('automaticUpdateChecks');
    final previousCheck = preferences.getInt('update_check_foss');
    addTearDown(() async {
      await server.close(force: true);
      if (previous == null) {
        await preferences.remove('automaticUpdateChecks');
      } else {
        await preferences.setBool('automaticUpdateChecks', previous);
      }
      if (previousCheck == null) {
        await preferences.remove('update_check_foss');
      } else {
        await preferences.setInt('update_check_foss', previousCheck);
      }
    });
    UpdateService createService() => UpdateService(
      channel: UpdateChannel.foss,
      get: (url) {
        hosts.add(url.host);
        return http.get(Uri.http('127.0.0.1:${server.port}', url.path));
      },
    );
    final settings = SettingsViewModel();
    await settings.loadSettings();
    await settings.setAutomaticUpdateChecks(false);
    await preferences.remove('update_check_foss');
    var updates = createService();
    await updates.check(automatic: true);
    expect(requests, 0);
    expect(hosts, isEmpty);
    updates.dispose();
    final restored = SettingsViewModel();
    await restored.loadSettings();
    expect(restored.settings.automaticUpdateChecks, isFalse);
    updates = createService();
    await updates.check(automatic: true);
    expect(requests, 0);
    expect(preferences.containsKey('update_check_foss'), isFalse);
    await updates.check();
    expect(requests, 2);
    expect(hosts, containsAll(['api.github.com', 'f-droid.org']));
    hosts.clear();
    await restored.setAutomaticUpdateChecks(true);
    expect(
      (await SettingsService().getSettings()).automaticUpdateChecks,
      isTrue,
    );
    await updates.check(automatic: true);
    expect(requests, 4);
    await updates.check(automatic: true);
    expect(requests, 4);
    await restored.setAutomaticUpdateChecks(false);
    await updates.check(automatic: true);
    expect(requests, 4);
    updates.dispose();
    settings.dispose();
    restored.dispose();
  });
}
