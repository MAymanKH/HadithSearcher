import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/models/settings.dart';

import '../tool/dropdown_lab/main.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
  setUpAll(() async {
    if (!capture) return;
    for (final font in {
      'Cairo': 'assets/fonts/Cairo-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final config in [
    (
      name: 'ar-light',
      ar: true,
      brightness: Brightness.light,
      palette: ColorSchemePreference.classic,
      scale: 1.0,
      width: 390.0,
    ),
    (
      name: 'ar-dark',
      ar: true,
      brightness: Brightness.dark,
      palette: ColorSchemePreference.classic,
      scale: 1.0,
      width: 390.0,
    ),
    (
      name: 'ar-forest',
      ar: true,
      brightness: Brightness.light,
      palette: ColorSchemePreference.forest,
      scale: 1.0,
      width: 390.0,
    ),
    (
      name: 'en-light',
      ar: false,
      brightness: Brightness.light,
      palette: ColorSchemePreference.classic,
      scale: 1.0,
      width: 390.0,
    ),
    (
      name: 'ar-large',
      ar: true,
      brightness: Brightness.dark,
      palette: ColorSchemePreference.classic,
      scale: 2.0,
      width: 320.0,
    ),
  ]) {
    for (final style in PickerStyle.values) {
      testWidgets('${style.name} ${config.name} selection flow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(config.width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(config.palette, config.brightness),
              locale: Locale(config.ar ? 'ar' : 'en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(config.scale)),
                child: child!,
              ),
              home: PickerScene(style: style, arabic: config.ar),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> shot(String state) async {
          expect(tester.takeException(), isNull);
          if (!capture) return;
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('build/dropdown-lab')
              ..createSync(recursive: true);
            await File(
              '${directory.path}/${style.name}-${config.name}-$state.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await shot('closed');
        await tester.ensureVisible(find.byKey(const Key('mode-field')));
        await tester.tap(find.byKey(const Key('mode-field')));
        await tester.pumpAndSettle();
        await shot('single');
        final anyWord = config.ar ? 'أي كلمة' : 'Any word';
        await tester.tap(find.text(anyWord));
        await tester.pumpAndSettle();
        expect(find.text(anyWord), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('books-field')));
        await tester.tap(find.byKey(const Key('books-field')));
        await tester.pumpAndSettle();
        await shot('multiple');
        final search = find.byKey(const Key('sheet-search'));
        await tester.enterText(search, config.ar ? 'الترمذي' : 'Tirmidhi');
        await tester.pumpAndSettle();
        expect(
          find.text(config.ar ? 'صحيح البخاري' : 'Sahih al-Bukhari'),
          findsNothing,
        );
        final choice = find.text(
          config.ar ? 'جامع الترمذي' : 'Jami al-Tirmidhi',
        );
        expect(choice, findsOneWidget);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        if (style != PickerStyle.current) {
          await tester.tap(find.text(config.ar ? 'تطبيق' : 'Apply'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(
            find.textContaining(
              config.ar ? 'جامع الترمذي' : 'Jami al-Tirmidhi',
            ),
            findsOneWidget,
          );
          // Dismissing a second edit keeps the previously applied selection.
          await tester.tap(find.byKey(const Key('books-field')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(config.ar ? 'صحيح مسلم' : 'Sahih Muslim'));
          await tester.tap(find.byTooltip(config.ar ? 'إغلاق' : 'Close'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining(config.ar ? 'صحيح مسلم' : 'Sahih Muslim'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
