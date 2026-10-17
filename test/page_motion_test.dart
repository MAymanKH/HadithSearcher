import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/viewmodels/similar_hadith_viewmodel.dart';
import 'package:hadithsearcher/views/privacy/telemetry_consent_view.dart';
import 'package:hadithsearcher/views/settings/settings_view.dart';
import 'package:hadithsearcher/views/similar_hadith/similar_hadith_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry/fake_backend.dart';

void main() {
  for (final consent in [false, true]) {
    testWidgets(
      '${consent ? 'settings consent' : 'similar hadith'} uses platform page transitions',
      (tester) async {
        SharedPreferences.setMockInitialValues({'language': 'en'});
        final settings = SettingsViewModel();
        await settings.loadSettings();
        final telemetry = TelemetryService(
          preferences: await SharedPreferences.getInstance(),
          backend: FakeBackend(),
        );
        final similar = SimilarHadithViewModel();
        addTearDown(settings.dispose);
        addTearDown(telemetry.dispose);
        addTearDown(similar.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: telemetry),
              ChangeNotifierProvider.value(value: similar),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: consent
                  ? const SettingsView()
                  : Builder(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const SimilarHadithView(),
                            ),
                          ),
                          child: const Text('Open similar'),
                        ),
                      ),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (consent) {
          await tester.scrollUntilVisible(
            find.text('Privacy and optional analytics'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Privacy and optional analytics'));
        } else {
          await tester.tap(find.text('Open similar'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final page = find.byType(
          consent ? TelemetryConsentView : SimilarHadithView,
        );
        final theme = Theme.of(tester.element(page));
        expect(theme.pageTransitionsTheme, const PageTransitionsTheme());
        final route = ModalRoute.of(tester.element(page))!;
        expect(route, isA<MaterialPageRoute<void>>());
        expect(route.animation!.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(page).dx, 0);
        Navigator.pop(tester.element(page));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(route.animation!.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(page, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
