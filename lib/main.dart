import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/shared_text_service.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/telemetry/telemetry_service.dart';
import 'services/telemetry/sdk_telemetry_backend.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Bundled font copyright notices'],
      await rootBundle.loadString('assets/fonts/NOTICE.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const [
        'Amiri',
        'Aref Ruqaa',
        'Cairo',
        'Gulzar',
        'Lateef',
        'Reem Kufi',
        'Rubik',
        'Tajawal',
        'Noto Naskh Arabic'
      ],
      await rootBundle.loadString('assets/fonts/LICENSE-OFL.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Roboto'],
      await rootBundle.loadString('assets/fonts/LICENSE-Apache-2.0.txt'),
    );
  });

  final telemetry = TelemetryService(
    preferences: await SharedPreferences.getInstance(),
    backend: SdkTelemetryBackend(),
    policy: buildTelemetryPolicy,
  );
  TelemetryService.instance = telemetry;
  await telemetry.initialize();

  await SharedTextService.instance.initialize();

  // Initialize database (for favourites)
  final db = DatabaseService();
  await TelemetryService.trace('database.initialize', () => db.database);

  // Load appearance before the first Flutter frame.
  final settingsService = SettingsService();
  final initialSettings = await settingsService.getSettings();

  runApp(
    HadithSearcherApp(
      initialThemeMode: initialSettings.themeMode,
      initialColorScheme: initialSettings.colorScheme,
      telemetry: telemetry,
      startupReady: binding.waitUntilFirstFrameRasterized.then(
        (_) => Future<void>.delayed(const Duration(milliseconds: 200)),
      ),
    ),
  );
}
