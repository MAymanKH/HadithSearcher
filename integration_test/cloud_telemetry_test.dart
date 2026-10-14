import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/services/telemetry/sdk_telemetry_backend.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'send an explicitly consented synthetic event to both configured services',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final backend = SdkTelemetryBackend(environment: 'verification');
    final telemetry =
        TelemetryService(preferences: preferences, backend: backend);
    await telemetry.save(diagnostics: true, analytics: true);
    expect(telemetry.error, isNull);
    await backend.capture('telemetry_integration_verified', {
      'verification': true,
      'sdk_path': 'android_native',
    });
    await backend.report(StateError('Synthetic integration check'),
        StackTrace.current, 'verification.sentry');
    await Posthog().flush();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 5)));
    await telemetry.save(diagnostics: false, analytics: false);
    telemetry.dispose();
  }, skip: !const bool.fromEnvironment('VERIFY_TELEMETRY_CLOUD'));
}
