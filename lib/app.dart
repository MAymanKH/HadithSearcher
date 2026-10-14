import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/constants/routes.dart';
import 'core/theme/app_theme.dart';
import 'viewmodels/favourites_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/similar_hadith_viewmodel.dart';
import 'views/main_shell.dart';
import 'views/similar_hadith/similar_hadith_view.dart';
import 'services/telemetry/telemetry_service.dart';
import 'views/privacy/telemetry_consent_view.dart';

/// Main app widget with Provider setup.
class HadithSearcherApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  final TelemetryService telemetry;

  const HadithSearcherApp({
    super.key,
    required this.initialThemeMode,
    required this.telemetry,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: telemetry),
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => FavouritesViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => SimilarHadithViewModel(),
        ),
      ],
      child: Consumer<SettingsViewModel>(
        builder: (context, settingsVm, _) {
          // Use initial theme until settings are loaded
          final themeMode =
              settingsVm.isLoading ? initialThemeMode : settingsVm.themeMode;

          return MaterialApp(
            localizationsDelegates: const [
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ar', 'AE'),
            ],
            locale: const Locale('ar', 'AE'),
            title: 'Hadith Searcher',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            debugShowCheckedModeBanner: false,
            home: Consumer<TelemetryService>(
              builder: (context, service, child) => !service.needsConsent
                  ? const MainShell()
                  : const TelemetryConsentView(firstLaunch: true),
            ),
            routes: {
              searchRoute: (context) => const MainShell(initialIndex: 0),
              similarHadithRoute: (context) => const SimilarHadithView(),
              favouritesRoute: (context) => const MainShell(initialIndex: 1),
              settingsRoute: (context) => const MainShell(initialIndex: 2),
              aboutRoute: (context) => const MainShell(initialIndex: 3),
            },
          );
        },
      ),
    );
  }
}
