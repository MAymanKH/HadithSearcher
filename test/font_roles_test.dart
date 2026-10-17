import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/api_details_sheet.dart';
import 'package:hadithsearcher/widgets/hadith_card_layout.dart';
import 'package:hadithsearcher/widgets/hadith_reading_sheet.dart';

import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/services/update_service.dart';
import 'package:hadithsearcher/views/about/about_view.dart';
import 'package:hadithsearcher/views/settings/settings_view.dart';
import 'package:hadithsearcher/views/welcome/welcome_view.dart';
import 'package:hadithsearcher/views/privacy/telemetry_consent_view.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/hadith_additional_info.dart';
import 'package:hadithsearcher/widgets/hadith_detail_button.dart';

import 'telemetry/fake_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final language in ['ar', 'en']) {
      testWidgets('interface uses Cairo in $language ${theme.brightness}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = SettingsViewModel();
        await settings.loadSettings();
        addTearDown(settings.dispose);
        final updates = UpdateService();
        addTearDown(updates.dispose);
        final telemetry = TelemetryService(
          preferences: await SharedPreferences.getInstance(),
          backend: FakeBackend(),
        );
        addTearDown(telemetry.dispose);

        void expectInterfaceFont() {
          final texts = tester.widgetList<RichText>(find.byType(RichText));
          expect(texts, isNotEmpty);
          for (final text in texts) {
            if (text.text.style?.fontFamily == 'MaterialIcons') continue;
            expect(
              text.text.style?.fontFamily,
              'Cairo',
              reason: text.text.toPlainText(),
            );
          }
        }

        for (final page in const [
          WelcomeView(),
          SettingsView(),
          AboutView(),
          TelemetryConsentView(),
        ]) {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider.value(value: updates),
                ChangeNotifierProvider.value(value: telemetry),
              ],
              child: MaterialApp(
                theme: theme,
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expectInterfaceFont();
          if (page is SettingsView) {
            await tester.tap(find.byType(AppDropdown<String>).last);
            await tester.pumpAndSettle();
            expectInterfaceFont();
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets(
        'card metadata follows reading settings in $language ${theme.brightness}',
        (tester) async {
          final settings = SettingsViewModel();
          addTearDown(settings.dispose);
          final hadith = Hadith.fromJson({
            'hadith': 'نص الحديث',
            'grade': 'صحيح',
            'explainGrade': 'تفصيل من المصدر',
          });
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: settings,
              child: MaterialApp(
                theme: theme,
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        HadithAdditionalInfo(hadith: hadith),
                        HadithDetailButton(
                          icon: Icons.article_rounded,
                          label: 'Details',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(HadithAdditionalInfo));
          await tester.tap(find.text(context.l10n.additionalInfo));
          await tester.pumpAndSettle();
          for (final font in ['Roboto', 'Tajawal', 'Cairo']) {
            await settings.setFontFamily(font);
            await settings.setFontSize(font == 'Tajawal' ? 24 : 20);
            await settings.setFontWeight(
              font == 'Tajawal'
                  ? FontWeightPreference.bold
                  : FontWeightPreference.normal,
            );
            await tester.pumpAndSettle();
            final header = tester.widget<Text>(
              find.text(context.l10n.hideAdditionalInfo),
            );
            expect(header.style!.fontFamily, font);
            expect(header.style!.fontSize, settings.fontSize);
            expect(header.style!.fontWeight, settings.fontWeight);
            final button = tester.widget<OutlinedButton>(
              find.byType(OutlinedButton),
            );
            final buttonStyle = button.style!.textStyle!.resolve({})!;
            expect(buttonStyle.fontFamily, font);
            expect(buttonStyle.fontSize, settings.fontSize * .8);
            expect(buttonStyle.fontWeight, settings.fontWeight);
            final line = tester.widget<SelectableText>(
              find.byType(SelectableText).first,
            );
            expect(line.style!.fontFamily, font);
            expect(line.style!.fontSize, settings.fontSize);
            expect(line.style!.fontWeight, settings.fontWeight);
            expect(
              line.data,
              '${context.l10n.gradeExplanation}: تفصيل من المصدر',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        'reading fonts stay independent in $language ${theme.brightness}',
        (tester) async {
          final settings = SettingsViewModel();
          addTearDown(settings.dispose);
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: settings,
              child: MaterialApp(
                theme: theme,
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => SingleChildScrollView(
                      child: Column(
                        children: [
                          HadithCardLayout(
                            text: 'نص الحديث',
                            grading: context.l10n.gradeLabel('صحيح'),
                            attribution: 'المصدر',
                            isFavourite: false,
                            onExplanation: () {},
                            onSimilar: null,
                            onShare: () {},
                            onFavourite: () {},
                            onAlternate: null,
                          ),
                          TextButton(
                            onPressed: () => showExplanationSheet(
                              context,
                              load: () async => ApiResult.success('نص الشرح'),
                            ),
                            child: const Text('explanation'),
                          ),
                          TextButton(
                            onPressed: () => showApiDetailsSheet<String>(
                              context,
                              title: context.l10n.additionalInfo,
                              load: () async =>
                                  ApiResult.success('محتوى المصدر'),
                              format: (value) => value,
                            ),
                            child: const Text('source'),
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

          void expectReadingFont(String font) {
            void expectSpanStyle(InlineSpan span, TextStyle inherited) {
              final style = inherited.merge(span.style);
              expect(style.fontFamily, font);
              expect(style.fontWeight, settings.fontWeight);
              if (span is TextSpan) {
                for (final child in span.children ?? <InlineSpan>[]) {
                  expectSpanStyle(child, style);
                }
              }
            }

            for (final text in tester.widgetList<SelectableText>(
              find.byType(SelectableText),
            )) {
              if (text.textSpan != null) {
                expectSpanStyle(text.textSpan!, text.style!);
              }
            }
            // EditableText contains the effective style after theme inheritance.
            final texts = tester.widgetList<EditableText>(
              find.byType(EditableText),
            );
            expect(texts, isNotEmpty);
            for (final text in texts) {
              expect(text.style.fontFamily, font);
              expect(text.style.fontSize, settings.fontSize);
              expect(text.style.fontWeight, settings.fontWeight);
              expect(
                text.style.fontFamilyFallback ?? [],
                isNot(contains('Cairo')),
              );
            }
          }

          for (final font in ['Roboto', 'Tajawal', 'Cairo']) {
            await settings.setFontFamily(font);
            await settings.setFontSize(font == 'Tajawal' ? 24 : 20);
            await settings.setFontWeight(
              font == 'Tajawal'
                  ? FontWeightPreference.bold
                  : FontWeightPreference.normal,
            );
            await tester.pumpAndSettle();
            expectReadingFont(font);
            final cardLabel = tester.widget<Text>(
              find.descendant(
                of: find.byType(HadithCardLayout),
                matching: find.text(language == 'ar' ? 'الشرح' : 'Explanation'),
              ),
            );
            expect(cardLabel.style!.fontFamily, 'Cairo');
            expect(cardLabel.style!.fontWeight, settings.fontWeight);
            expect(cardLabel.style!.fontSize, settings.fontSize * .6);
            for (final action in ['explanation', 'source']) {
              await tester.tap(find.text(action));
              await tester.pumpAndSettle();
              expectReadingFont(font);
              Navigator.of(tester.element(find.byType(BottomSheet))).pop();
              await tester.pumpAndSettle();
            }
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
