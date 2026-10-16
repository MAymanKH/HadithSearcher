import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/services/settings_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/appearance_preferences.dart';
import 'package:hadithsearcher/widgets/hadith_card_layout.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color foreground, Color background) {
  final values = [
    Color.alphaBlend(foreground, background).computeLuminance(),
    background.computeLuminance(),
  ]..sort();
  return (values.last + .05) / (values.first + .05);
}

void main() {
  const capture = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!capture) return;
    for (final entry in {
      'Cairo': 'Cairo-Variable.ttf',
      'Roboto': 'Roboto-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test(
    'only generated palettes define colors and only themes derive colors',
    () {
      final rawColors = RegExp(
        r'\bColors\.|\bColor\s*\(|\bColor\.from\w+\s*\('
        r'|0x[\da-fA-F]{6,8}|#[\da-fA-F]{6}\b',
      );
      final derivedColors = RegExp(
        r'\bColor\.(?:lerp|alphaBlend)\s*\(|\.with(?:Values|Opacity|Alpha)\s*\(',
      );
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') ||
            file.path.endsWith('app_palettes.g.dart')) {
          continue;
        }
        final source = file.readAsStringSync();
        expect(rawColors.allMatches(source), isEmpty, reason: file.path);
        if (!file.path.contains('core/theme/')) {
          expect(derivedColors.allMatches(source), isEmpty, reason: file.path);
        }
      }
    },
  );

  test(
    'old, missing, and unknown scheme preferences fall back safely',
    () async {
      for (final value in [null, 'retired-scheme']) {
        SharedPreferences.setMockInitialValues({
          'theme': 'dark',
          if (value != null) 'colorScheme': value,
        });
        final settings = await SettingsService().getSettings();
        expect(settings.colorScheme, ColorSchemePreference.classic);
        expect(settings.theme, ThemePreference.dark);
      }
      expect(
        AppSettings.fromDatabase({'colorScheme': 'forest'}).colorScheme,
        ColorSchemePreference.forest,
      );
    },
  );

  test('all schemes persist independently from brightness and reset', () async {
    final vm = SettingsViewModel();
    addTearDown(vm.dispose);
    await vm.loadSettings();
    await vm.setTheme(ThemePreference.dark);
    for (final palette in ColorSchemePreference.values) {
      await vm.setColorScheme(palette);
      expect(vm.settings.theme, ThemePreference.dark);
      final reloaded = await SettingsService().getSettings();
      expect(reloaded.colorScheme, palette);
      expect(reloaded.theme, ThemePreference.dark);
    }
    await vm.setTheme(ThemePreference.light);
    expect(vm.settings.colorScheme, ColorSchemePreference.highContrast);
    await vm.resetToDefaults();
    final reset = await SettingsService().getSettings();
    expect(reset.colorScheme, ColorSchemePreference.classic);
    expect(reset.theme, ThemePreference.system);
  });

  for (final palette in ColorSchemePreference.values) {
    for (final brightness in Brightness.values) {
      final name = '${palette.name}-${brightness.name}';
      final theme = AppTheme.build(palette, brightness);
      final colors = theme.colorScheme;
      final textMinimum = palette == ColorSchemePreference.highContrast
          ? 7.0
          : 4.5;
      test('$name text and control contrast', () {
        expect(theme.brightness, brightness);
        for (final background in [
          colors.surface,
          colors.surfaceContainer,
          colors.surfaceContainerHigh,
        ]) {
          for (final foreground in [
            colors.onSurface,
            colors.onSurfaceVariant,
            colors.primary,
            colors.error,
          ]) {
            expect(
              contrast(foreground, background),
              greaterThanOrEqualTo(textMinimum),
            );
          }
          expect(contrast(colors.outline, background), greaterThanOrEqualTo(3));
        }
        for (final pair in [
          (colors.onPrimary, colors.primary),
          (colors.onPrimaryContainer, colors.primaryContainer),
          (colors.onSecondary, colors.secondary),
          (colors.onSecondaryContainer, colors.secondaryContainer),
          (colors.onInverseSurface, colors.inverseSurface),
          (AppTheme.unavailableActionForeground(colors), colors.inverseSurface),
          (colors.onError, colors.error),
          (colors.onErrorContainer, colors.errorContainer),
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(textMinimum));
        }
        final selected = {WidgetState.selected};
        expect(
          contrast(
            theme.checkboxTheme.checkColor!.resolve(selected)!,
            theme.checkboxTheme.fillColor!.resolve(selected)!,
          ),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrast(
            theme.switchTheme.thumbColor!.resolve(selected)!,
            theme.switchTheme.trackColor!.resolve(selected)!,
          ),
          greaterThanOrEqualTo(3),
        );
        expect(theme.snackBarTheme.backgroundColor, colors.inverseSurface);
        expect(
          theme.snackBarTheme.contentTextStyle!.color,
          colors.onInverseSurface,
        );
        expect(
          theme.navigationBarTheme.iconTheme!.resolve(selected)!.color,
          colors.onSecondaryContainer,
        );
      });

      testWidgets(
        '$name renders reading content, actions, and appearance choices',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final vm = SettingsViewModel();
          addTearDown(vm.dispose);
          await vm.loadSettings();
          await vm.setColorScheme(palette);
          await vm.setFontFamily('Cairo');
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: vm,
              child: MaterialApp(
                theme: theme,
                locale: const Locale('ar'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    appBar: AppBar(title: const Text('البحث في الحديث')),
                    body: SingleChildScrollView(
                      child: Column(
                        children: [
                          const AppearancePreferences(),
                          HadithCardLayout(
                            text:
                                'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى',
                            narrator: 'عمر بن الخطاب',
                            grading: 'صحيح',
                            attribution:
                                'الراوي: عمر بن الخطاب | المحدث: البخاري',
                            isFavourite: false,
                            onExplanation: () {},
                            onSimilar: null,
                            onShare: () {},
                            onFavourite: () {},
                            onAlternate: null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final text = tester.widget<SelectableText>(
            find.byType(SelectableText).first,
          );
          expect(text.style!.color, colors.onSurface);
          final prefix = text.textSpan!.children!.first as TextSpan;
          expect(prefix.style!.color, colors.onSurfaceVariant);
          for (final available in [true, false]) {
            final button = tester.widget<TextButton>(
              find.widgetWithText(TextButton, available ? 'الشرح' : 'مشابهة'),
            );
            final foreground = button.style!.foregroundColor!.resolve({})!;
            expect(
              contrast(foreground, colors.inverseSurface),
              greaterThanOrEqualTo(textMinimum),
            );
          }
          if (capture) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final path = File('/tmp/hadith-themes/$name.png');
              await path.parent.create(recursive: true);
              await path.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('color-scheme-selector')));
          await tester.pumpAndSettle();
          for (final label in [
            'كلاسيكي',
            'بني دافئ',
            'أزرق رمادي',
            'أخضر هادئ',
            'تباين عالٍ',
          ]) {
            expect(find.text(label), findsWidgets);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
