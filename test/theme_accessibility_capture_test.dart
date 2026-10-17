import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/app_loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/search_catalogs.dart';
import 'telemetry/fake_backend.dart';

// Captures actual app screens with cached filter data and telemetry disabled.
// flutter test test/theme_accessibility_capture_test.dart \
//   --dart-define=CAPTURE_SCREENSHOTS=true \
//   --dart-define=THEME_SCREENSHOT_DIR=/tmp/hadith-themes-before
void main() {
  const capture = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
  const directory = String.fromEnvironment(
    'THEME_SCREENSHOT_DIR',
    defaultValue: '/tmp/hadith-themes',
  );

  setUpAll(() async {
    if (!capture) return;
    for (final entry in {
      'Cairo': 'assets/fonts/Cairo-Variable.ttf',
      'Roboto': 'assets/fonts/Roboto-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  for (final palette in [
    ColorSchemePreference.sepia,
    ColorSchemePreference.highContrast,
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('${palette.name}-${brightness.name} app screenshots', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'welcomeCompleted': true,
          'theme': brightness.name,
          'colorScheme': palette.name,
          'language': 'ar',
          'fontFamily': 'Cairo',
        });
        await seedCatalogCache();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final telemetry = TelemetryService(
          preferences: await SharedPreferences.getInstance(),
          backend: FakeBackend(),
        );
        await telemetry.save(diagnostics: false, analytics: false);
        addTearDown(telemetry.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: HadithSearcherApp(
              initialThemeMode: brightness == Brightness.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              initialColorScheme: palette,
              telemetry: telemetry,
            ),
          ),
        );
        final vm = tester
            .element(find.byType(MaterialApp))
            .read<SearchViewModel>();
        await finishCatalogPreload(tester, vm.preloadCatalogs());
        await tester.pumpAndSettle();

        Future<void> screenshot(String state) async {
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '$directory/${palette.name}-${brightness.name}-$state.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.tap(find.widgetWithText(TextButton, 'التصفية'));
        vm.setSaveAdvancedSettings(false);
        await tester.pumpAndSettle();
        await screenshot('search');
        await tester.tap(
          find
              .ancestor(
                of: find.text('درجة الحديث', findRichText: true).first,
                matching: find.byType(InputDecorator),
              )
              .first,
        );
        await tester.runAsync(() async {
          for (var i = 0; i < 200; i++) {
            await tester.pump();
            if (find.byType(AppLoadingIndicator).evaluate().isEmpty) break;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.tap(find.text('جميع الدرجات').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('أحاديث صحيحة').last);
        await tester.pumpAndSettle();
        await screenshot('checkboxes');
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('الإعدادات').last);
        await tester.pumpAndSettle();
        final dropdown = find.byType(AppDropdown<String>).first;
        final ink = tester.widget<InkWell>(
          find.descendant(of: dropdown, matching: find.byType(InkWell)).first,
        );
        // Use the real focus node, so the screenshot includes keyboard focus.
        final inkContext = tester.element(
          find
              .descendant(of: dropdown, matching: find.byType(InputDecorator))
              .first,
        );
        Focus.of(inkContext).requestFocus();
        await tester.pumpAndSettle();
        expect(ink.onTap, isNotNull);
        await screenshot('focus');
        await tester.pumpWidget(const SizedBox());
      }, skip: !capture);
    }
  }
}
