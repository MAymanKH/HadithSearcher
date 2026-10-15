import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/views/privacy/telemetry_consent_view.dart';
import 'fake_backend.dart';

void main() {
  testWidgets(
      'first launch requires explicit choice and defaults both options off',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = FakeBackend();
    final service = TelemetryService(
        preferences: await SharedPreferences.getInstance(), backend: backend);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: service,
      child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
        textDirection: TextDirection.rtl,
        child: TelemetryConsentView(firstLaunch: true),
      )),
    ));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const Key('analytics-consent')))
            .value,
        false);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const Key('diagnostics-consent')))
            .value,
        false);
    expect(backend.transitions, isEmpty);
    await tester.tap(find.byKey(const Key('diagnostics-consent')));
    await tester.pump();
    expect(backend.transitions, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('save-telemetry-consent')));
    await tester.tap(find.byKey(const Key('save-telemetry-consent')));
    await tester.pumpAndSettle();
    expect(service.consent.diagnostics, true);
    expect(service.consent.analytics, false);
    service.dispose();
  });

  testWidgets(
      'rejecting takes one action and persists without enabling either SDK',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = FakeBackend();
    final service = TelemetryService(
        preferences: await SharedPreferences.getInstance(), backend: backend);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: service,
      child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TelemetryConsentView(firstLaunch: true)),
    ));
    await tester.ensureVisible(find.byKey(const Key('save-telemetry-consent')));
    await tester.tap(find.byKey(const Key('save-telemetry-consent')));
    await tester.pumpAndSettle();
    expect(service.consent.decided, true);
    expect(backend.transitions, isNot(contains('diagnostics:true')));
    expect(backend.transitions, isNot(contains('analytics:true')));
    service.dispose();
  });
}
