import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/appearance_preferences.dart';
import 'package:hadithsearcher/widgets/color_scheme_card_preview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!capture) return;
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final language in ['ar', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$language ${brightness.name} card previews fit a narrow phone with large text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 750);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final vm = SettingsViewModel();
          addTearDown(vm.dispose);
          await vm.loadSettings();
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: vm,
              child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  theme: AppTheme.build(
                    ColorSchemePreference.classic,
                    brightness,
                  ),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: const Scaffold(
                    body: SingleChildScrollView(child: AppearancePreferences()),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ColorSchemeCardPreview), findsNothing);
          await tester.tap(find.byKey(const Key('color-scheme-selector')));
          await tester.pumpAndSettle();
          expect(find.byType(ColorSchemeCardPreview), findsWidgets);
          expect(
            tester.getSize(find.byType(ColorSchemeCardPreview).first),
            const Size(72, 52),
          );
          expect(tester.takeException(), isNull);
          if (capture) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/hadith-picker-$language-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final sheet = find.byType(BottomSheet);
          final label = ColorSchemePreference.graphite.label(
            tester.element(sheet).l10n,
          );
          final option = find.descendant(of: sheet, matching: find.text(label));
          final scrollable = find.descendant(
            of: sheet,
            matching: find.byType(Scrollable),
          );
          await tester.scrollUntilVisible(option, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
          // The list can still be settling under large text; re-align until
          // the option is hittable before tapping.
          await tester.scrollUntilVisible(option, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(vm.settings.colorScheme, ColorSchemePreference.graphite);
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.byType(ColorSchemeCardPreview), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
