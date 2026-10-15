import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/services/telemetry/sdk_telemetry_backend.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'real Android SDKs respect consent, send payloads, and discard queued data on withdrawal',
      (tester) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final bodies = <String>[];
    var accepting = true;
    var requests = 0;
    final subscription = server.listen((request) async {
      requests++;
      var bytes = await request
          .fold<List<int>>([], (buffer, data) => buffer..addAll(data));
      if (request.headers.value('content-encoding') == 'gzip') {
        bytes = gzip.decode(bytes);
      }
      if (accepting) bodies.add(utf8.decode(bytes));
      request.response.statusCode = accepting ? 200 : 503;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"status":1}');
      await request.response.close();
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('welcomeCompleted', true);
    final backend = SdkTelemetryBackend(
      sentryDsn: 'http://public@127.0.0.1:${server.port}/1',
      posthogToken: 'phc_local_test',
      posthogHost: 'http://127.0.0.1:${server.port}',
    );
    final telemetry =
        TelemetryService(preferences: preferences, backend: backend);
    TelemetryService.instance = telemetry;
    await telemetry.initialize();
    await tester.pumpWidget(HadithSearcherApp(
        initialThemeMode: ThemeMode.light, telemetry: telemetry));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('analytics-consent')), findsOneWidget);
    expect(requests, 0);
    expect(Sentry.isEnabled, false);
    await tester.ensureVisible(find.byKey(const Key('save-telemetry-consent')));
    await tester.tap(find.byKey(const Key('save-telemetry-consent')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(requests, 0);

    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('الخصوصية والقياس الاختياري'));
    await tester.tap(find.text('الخصوصية والقياس الاختياري'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diagnostics-consent')));
    await tester.tap(find.byKey(const Key('analytics-consent')));
    await tester.ensureVisible(find.byKey(const Key('save-telemetry-consent')));
    await tester.tap(find.byKey(const Key('save-telemetry-consent')));
    await tester.pumpAndSettle();
    expect(telemetry.consent.analytics, true);
    expect(telemetry.consent.diagnostics, true);
    expect(Sentry.isEnabled, true);

    final firstId = await backend.analyticsId();
    await backend.capture('search_submitted', {'query': 'consented-query'});
    await backend.report(StateError('secret-query@example.com'),
        StackTrace.current, 'integration.error');
    await Posthog().flush();
    await tester.runAsync(() async {
      for (var attempt = 0;
          attempt < 30 &&
              !bodies.any((body) => body.contains('search_submitted'));
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    });
    expect(
        bodies.any((body) =>
            body.contains('search_submitted') &&
            body.contains('consented-query')),
        true);
    expect(bodies.any((body) => body.contains('integration.error')), true);
    expect(bodies.join(), isNot(contains('secret-query@example.com')));

    accepting = false;
    await backend
        .capture('queued_before_withdrawal', {'query': 'queued-query'});
    await backend.report(StateError('queued diagnostic'), StackTrace.current,
        'queued_diagnostic');
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await telemetry.save(diagnostics: false, analytics: false);
    expect(Sentry.isEnabled, false);
    accepting = true;
    final afterWithdrawal = requests;
    TelemetryService.event('after_withdrawal');
    TelemetryService.report(
        StateError('declined'), StackTrace.current, 'declined');
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    expect(requests, afterWithdrawal);
    final restored =
        TelemetryService(preferences: preferences, backend: backend);
    await restored.initialize();
    expect(restored.consent.analytics || restored.consent.diagnostics, false);
    await restored.save(diagnostics: true, analytics: true);
    expect(await backend.analyticsId(), isNot(firstId));
    await backend.capture('after_reconsent', {});
    await Posthog().flush();
    await tester.runAsync(() async {
      for (var attempt = 0;
          attempt < 30 &&
              !bodies.any((body) => body.contains('after_reconsent'));
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    });
    expect(bodies.any((body) => body.contains('after_reconsent')), true);
    expect(bodies.join(), isNot(contains('queued_before_withdrawal')));
    expect(bodies.join(), isNot(contains('queued_diagnostic')));
    await restored.save(diagnostics: false, analytics: false);
    await tester.pumpWidget(const SizedBox());
    TelemetryService.instance = null;
    telemetry.dispose();
    restored.dispose();
    await subscription.cancel();
    await server.close(force: true);
  });
}
