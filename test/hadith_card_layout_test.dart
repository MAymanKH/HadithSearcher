import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/models/hadith_citation.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'package:hadithsearcher/viewmodels/favourites_viewmodel.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/favourites/favourites_view.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';
import 'package:hadithsearcher/widgets/hadith_card_layout.dart';

const hadith = Hadith(
  id: 'card',
  text: 'Hadith text',
  rawi: 'Narrator',
  mohdith: 'Scholar',
  book: 'Source',
  numberOrPage: '1/2',
  grade: 'Exact source grading\nincluding additional details',
  hasAlternateHadithSahih: true,
);

class SavedFavourites extends FavouritesViewModel {
  final List<FavouriteHadith> saved;
  SavedFavourites(this.saved);

  @override
  List<FavouriteHadith> get favourites => saved;
  @override
  bool get isLoading => false;
  @override
  bool get isEmpty => saved.isEmpty;
  @override
  Future<void> loadFavourites() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved citations preserve every field, including multiline grading', () {
    final restored = HadithCitation.tryParse(hadith.formattedInfo)!;
    expect(restored.formattedInfo, hadith.formattedInfo);
    expect(restored.grading, 'حكم Scholar: ${hadith.grade}');
    expect(restored.attribution, contains(hadith.rawi));
    expect(restored.attribution, contains(hadith.book));
    expect(restored.attribution, contains(hadith.numberOrPage));
    expect(HadithCitation.tryParse('legacy citation'), isNull);
    const sharedText =
        'Hadith text\n\n'
        'حكم Scholar: Exact source grading\nincluding additional details\n'
        'الراوي: Narrator\nالمصدر: Source\nالصفحة أو الرقم: 1/2';
    expect(hadith.shareText, sharedText);
    final saved = FavouriteHadith.fromDatabase({
      'id': 1,
      ...hadith.toDatabase(),
    });
    expect(saved.shareText, sharedText);
    const legacy = FavouriteHadith(
      id: 2,
      hadithId: 'legacy',
      hadithText: 'Legacy text',
      hadithInfo: 'Legacy citation\nUnstructured extra details',
    );
    expect(
      legacy.shareText,
      'Legacy text\n\nLegacy citation\nUnstructured extra details',
    );
  });

  for (final mode in ['light', 'dark']) {
    testWidgets(
      'card actions and large text fit a narrow phone in $mode mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = SettingsViewModel();
        addTearDown(settings.dispose);
        await settings.setFontSize(50);
        await settings.setPadding(30);
        final pressed = <String>[];
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              theme: mode == 'dark' ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HadithCardLayout(
                    text: hadith.text,
                    grading: 'خلاصة حكم المحدث: ${hadith.grade}',
                    scholar: 'المحدث: ${hadith.mohdith}',
                    attribution: hadith.citation.attribution,
                    isFavourite: true,
                    onExplanation: () => pressed.add('explanation'),
                    onSimilar: () => pressed.add('similar'),
                    onShare: () => pressed.add('share'),
                    onFavourite: () => pressed.add('favourite'),
                    onAlternate: () => pressed.add('alternate'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final textWidgets = tester.widgetList<SelectableText>(
          find.byType(SelectableText),
        );
        expect(
          textWidgets.map((text) => text.style!.fontSize),
          everyElement(50),
        );
        expect(textWidgets.map((text) => text.data), [
          hadith.text,
          'خلاصة حكم المحدث: ${hadith.grade}',
          'المحدث: ${hadith.mohdith}',
          hadith.citation.attribution,
        ]);
        expect(
          find.descendant(
            of: find.byType(HadithCardLayout),
            matching: find.byType(Tooltip),
          ),
          findsNothing,
        );
        expect(
          tester
              .widgetList<TextButton>(find.byType(TextButton))
              .map(
                (button) => (button.child! as Column).children
                    .whereType<Text>()
                    .single
                    .data,
              ),
          ['الشرح', 'مشابهة', 'المفضلة', 'مشاركة'],
        );
        for (final label in [
          'البديل الصحيح',
          'الشرح',
          'مشابهة',
          'مشاركة',
          'المفضلة',
        ]) {
          final action = label == 'البديل الصحيح'
              ? find.widgetWithText(OutlinedButton, label)
              : find.widgetWithText(TextButton, label);
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          await tester.tap(action);
          await tester.pumpAndSettle();
        }
        expect(pressed, [
          'alternate',
          'explanation',
          'similar',
          'share',
          'favourite',
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'saved cards retain complete legacy citations and match results',
    (tester) async {
      final settings = SettingsViewModel();
      addTearDown(settings.dispose);
      final favourites = SavedFavourites([
        FavouriteHadith(
          id: 1,
          hadithId: hadith.id,
          hadithText: hadith.text,
          hadithInfo: hadith.formattedInfo,
          hasAlternate: true,
        ),
        const FavouriteHadith(
          id: 2,
          hadithId: 'legacy',
          hadithText: 'Legacy text',
          hadithInfo: 'Legacy citation\nUnstructured extra details',
        ),
      ]);
      addTearDown(favourites.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider<FavouritesViewModel>.value(
              value: favourites,
            ),
          ],
          child: MaterialApp(home: const FavouritesView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('خلاصة حكم المحدث: ${hadith.grade}'), findsOneWidget);
      expect(find.text('المحدث: ${hadith.mohdith}'), findsOneWidget);
      expect(find.text(hadith.citation.attribution), findsOneWidget);
      expect(
        find.text('Legacy citation\nUnstructured extra details'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'البديل الصحيح'),
        findsOneWidget,
      );
      final saved = tester.widget<HadithCardLayout>(
        find.byType(HadithCardLayout).first,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: HadithCard(
                hadith: hadith,
                isFavourite: false,
                onFavouriteToggle: () async {},
              ),
            ),
          ),
        ),
      );
      final result = tester.widget<HadithCardLayout>(
        find.byType(HadithCardLayout),
      );
      expect(result.text, saved.text);
      expect(result.grading, saved.grading);
      expect(result.scholar, saved.scholar);
      expect(result.attribution, saved.attribution);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
