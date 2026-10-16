import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'package:hadithsearcher/viewmodels/favourites_viewmodel.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/favourites/favourites_view.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';
import 'package:hadithsearcher/widgets/hadith_card_layout.dart';

Hadith item(Map<String, Object?> metadata) => Hadith.fromJson({
  'hadithId': 'availability',
  'hadith': 'نص الحديث',
  'bookId': '1',
  'mohdithId': '1',
  ...metadata,
});

class SavedFavourites extends FavouritesViewModel {
  final FavouriteHadith saved;
  SavedFavourites(this.saved);
  @override
  List<FavouriteHadith> get favourites => [saved];
  @override
  bool get isLoading => false;
  @override
  bool get isEmpty => false;
  @override
  Future<void> loadFavourites() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('explanation availability accepts flags, IDs or returned text', () {
    for (final metadata in <Map<String, Object?>>[
      {'hasSharhMetadata': true},
      {
        'sharhMetadata': {'id': 123},
      },
      {
        'sharhMetadata': {'isContainSharh': true, 'sharh': 'الشرح'},
      },
    ]) {
      expect(item(metadata).hasExplanation, isTrue);
      expect(Hadith.fromJson(item(metadata).toJson()).hasExplanation, isTrue);
    }
    for (final metadata in <Map<String, Object?>>[
      {},
      {'hasSharhMetadata': false},
      {
        'sharhMetadata': {'id': 0, 'sharh': ' '},
      },
      {
        'sharhMetadata': {'id': '', 'isContainSharh': false},
      },
    ]) {
      expect(item(metadata).hasExplanation, isFalse);
    }
  });

  for (final similar in [false, true]) {
    for (final explanation in [false, true]) {
      testWidgets(
        'search and restored favourites agree: similar=$similar explanation=$explanation',
        (tester) async {
          final hadith = item({
            'hasSimilarHadith': similar,
            'hasSharhMetadata': explanation,
          });
          final settings = SettingsViewModel();
          addTearDown(settings.dispose);
          final saved = FavouriteHadith.fromDatabase({
            'id': 1,
            ...hadith.toDatabase(),
            'details': jsonEncode(hadith.toJson()),
          });
          final favourites = SavedFavourites(saved);
          addTearDown(favourites.dispose);
          for (final view in [
            HadithCard(
              hadith: hadith,
              isFavourite: false,
              onFavouriteToggle: () async {},
            ),
            const FavouritesView(),
          ]) {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: settings),
                  ChangeNotifierProvider<FavouritesViewModel>.value(
                    value: favourites,
                  ),
                ],
                child: MaterialApp(home: Scaffold(body: view)),
              ),
            );
            await tester.pumpAndSettle();
            final similarButton = find.widgetWithText(TextButton, 'مشابهة');
            final explanationButton = find.widgetWithText(TextButton, 'الشرح');
            expect(similarButton, findsOneWidget);
            expect(explanationButton, findsOneWidget);
            final layout = tester.widget<HadithCardLayout>(
              find.byType(HadithCardLayout),
            );
            expect(layout.onSimilar != null, similar);
            expect(layout.onExplanation != null, explanation);
            for (final (finder, available) in [
              (similarButton, similar),
              (explanationButton, explanation),
            ]) {
              final button = tester.widget<TextButton>(finder);
              expect(button.enabled, isTrue);
              final color = button.style!.foregroundColor!.resolve({})!;
              expect(color.a, closeTo(available ? 1 : 0.38, 0.01));
            }
            expect(
              tester
                  .widget<TextButton>(find.widgetWithText(TextButton, 'مشاركة'))
                  .enabled,
              isTrue,
            );
            expect(
              tester
                  .widget<TextButton>(
                    find.widgetWithText(TextButton, 'المفضلة'),
                  )
                  .enabled,
              isTrue,
            );
            await http.runWithClient(
              () async {
                if (!similar) {
                  await tester.tap(similarButton);
                  await tester.pumpAndSettle();
                  expect(
                    find.text('لا توجد أحاديث مشابهة لهذا الحديث'),
                    findsOneWidget,
                  );
                  expect(find.byType(HadithCardLayout), findsOneWidget);
                }
                if (!explanation) {
                  await tester.tap(explanationButton);
                  await tester.pumpAndSettle();
                  expect(find.text('لا يوجد شرح لهذا الحديث'), findsOneWidget);
                  expect(
                    find.text('لا توجد أحاديث مشابهة لهذا الحديث'),
                    findsNothing,
                  );
                }
                if (!similar || !explanation) {
                  await tester.pump(const Duration(seconds: 2));
                  await tester.pumpAndSettle();
                  expect(find.byType(SnackBar), findsNothing);
                }
              },
              () => MockClient(
                (_) async =>
                    throw StateError('Unavailable action used network'),
              ),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        },
      );
    }
  }

  testWidgets(
    'a returned explanation opens directly without a network request',
    (tester) async {
      final hadith = item({
        'sharhMetadata': {'id': '123', 'sharh': 'الشرح الموجود في نتائج البحث'},
      });
      final settings = SettingsViewModel();
      addTearDown(settings.dispose);
      await http.runWithClient(
        () async {
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
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'الشرح'));
          await tester.pumpAndSettle();
          expect(find.text(hadith.explanation!), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (_) async =>
              throw StateError('Returned explanation was downloaded again'),
        ),
      );
    },
  );
}
