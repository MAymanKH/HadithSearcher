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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final language in ['ar', 'en']) {
      testWidgets('interface uses Cairo in $language ${theme.brightness}', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(builder: (context) => Text(context.l10n.settings)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rendered = tester.widget<RichText>(find.byType(RichText).first);
        expect(rendered.text.style!.fontFamily, 'Cairo');
      });

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
                            grading: 'صحيح',
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
            // EditableText contains the effective style after theme inheritance.
            final texts = tester.widgetList<EditableText>(
              find.byType(EditableText),
            );
            expect(texts, isNotEmpty);
            for (final text in texts) {
              expect(text.style.fontFamily, font);
              expect(
                text.style.fontFamilyFallback ?? [],
                isNot(contains('Cairo')),
              );
            }
          }

          for (final font in ['Roboto', 'Tajawal', 'Cairo']) {
            await settings.setFontFamily(font);
            await tester.pumpAndSettle();
            expectReadingFont(font);
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
