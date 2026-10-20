import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/views/privacy/telemetry_consent_view.dart';
import 'fake_backend.dart';

void main() {
  for (final diagnostics in [false, true]) {
    for (final analytics in [false, true]) {
      testWidgets(
        'first launch saves diagnostics=$diagnostics analytics=$analytics after Continue',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final backend = FakeBackend();
          final service = TelemetryService(
            preferences: await SharedPreferences.getInstance(),
            backend: backend,
          );
          TelemetryService.instance = service;
          addTearDown(() {
            TelemetryService.instance = null;
            service.dispose();
          });
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: service,
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: const TelemetryConsentView(firstLaunch: true),
              ),
            ),
          );
          for (final key in ['analytics-consent', 'diagnostics-consent']) {
            expect(
              tester.widget<CheckboxListTile>(find.byKey(Key(key))).value,
              true,
            );
          }
          if (!diagnostics) {
            await tester.tap(find.byKey(const Key('diagnostics-consent')));
          }
          if (!analytics) {
            await tester.tap(find.byKey(const Key('analytics-consent')));
          }
          await tester.pump();
          TelemetryService.event('before_continue');
          TelemetryService.report(
            StateError('before_continue'),
            StackTrace.current,
            'test',
          );
          expect(service.analyticsEnabled || service.diagnosticsEnabled, false);
          expect(backend.transitions, isEmpty);
          expect(backend.events, isEmpty);
          expect(backend.reports, isEmpty);
          await tester.ensureVisible(
            find.byKey(const Key('save-telemetry-consent')),
          );
          await tester.tap(find.byKey(const Key('save-telemetry-consent')));
          await tester.pumpAndSettle();
          expect(service.consent.decided, true);
          expect(service.consent.diagnostics, diagnostics);
          expect(service.consent.analytics, analytics);
          expect(backend.diagnostics, diagnostics);
          expect(backend.analytics, analytics);
          final restarted = TelemetryService(
            preferences: service.preferences,
            backend: FakeBackend(),
          );
          expect(restarted.consent.diagnostics, diagnostics);
          expect(restarted.consent.analytics, analytics);
          restarted.dispose();
        },
      );
    }
  }

  testWidgets('privacy settings preserve saved choices', (tester) async {
    SharedPreferences.setMockInitialValues({
      TelemetryService.consentKey: const TelemetryConsent(
        decided: true,
        diagnostics: true,
      ).encode(),
    });
    final service = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: FakeBackend(),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: const MaterialApp(home: TelemetryConsentView()),
      ),
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('diagnostics-consent')),
          )
          .value,
      true,
    );
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('analytics-consent')))
          .value,
      false,
    );
  });
}
