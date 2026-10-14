import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';

import '../test/telemetry/fake_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('the compiled store flavor controls consent and settings', (
    tester,
  ) async {
    final isPlay = appFlavor == 'play';
    expect(appFlavor, isIn(['play', 'fdroid']));
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final backend = FakeBackend();
    final telemetry = TelemetryService(
      preferences: preferences,
      backend: backend,
      policy: buildTelemetryPolicy,
    );
    TelemetryService.instance = telemetry;
    await telemetry.initialize();
    await tester.pumpWidget(
      HadithSearcherApp(
        initialThemeMode: ThemeMode.light,
        telemetry: telemetry,
      ),
    );
    await tester.pumpAndSettle();
    expect(backend.analytics, isPlay);
    expect(backend.diagnostics, isPlay);
    expect(
      find.byKey(const Key('analytics-consent')),
      isPlay ? findsNothing : findsOneWidget,
    );
    if (!isPlay) {
      await tester.ensureVisible(
        find.byKey(const Key('save-telemetry-consent')),
      );
      await tester.tap(find.byKey(const Key('save-telemetry-consent')));
      await tester.pumpAndSettle();
    }
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    expect(
      find.text('الخصوصية والقياس الاختياري'),
      isPlay ? findsNothing : findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    TelemetryService.instance = null;
    telemetry.dispose();
  });
}
