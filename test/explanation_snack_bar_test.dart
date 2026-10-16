import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/services/explanation_service.dart';
import 'package:hadithsearcher/viewmodels/favourites_viewmodel.dart';
import 'package:hadithsearcher/views/favourites/favourites_view.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/widgets/app_snack_bar.dart';
import 'package:hadithsearcher/widgets/hadith_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const hadith = Hadith(
  id: 'explanation-snackbar',
  text: 'Hadith',
  rawi: '',
  mohdith: '',
  book: '',
  numberOrPage: '',
  grade: '',
  bookId: '1',
  hasSharhMetadata: true,
  sharhId: '123',
);

class SavedFavourites extends FavouritesViewModel {
  @override
  List<FavouriteHadith> get favourites => [
    FavouriteHadith(
      id: 1,
      hadithId: hadith.id,
      hadithText: hadith.text,
      hadithInfo: hadith.formattedInfo,
      sharhId: hadith.sharhId,
      details: hadith,
    ),
  ];

  @override
  bool get isLoading => false;

  @override
  bool get isEmpty => false;

  @override
  Future<void> loadFavourites() async {}

  @override
  Future<ApiResult<String>> getSharh(String hadithId) =>
      ExplanationService().getExplanation(hadithId, sharhId: hadith.sharhId);
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final directory = await Directory.systemTemp.createTemp(
      'explanation-notice-',
    );
    await databaseFactory.setDatabasesPath(directory.path);
    final db = await DatabaseService().database;
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final saved in [false, true]) {
    for (final earlierNotice in [false, true]) {
      testWidgets(
        'explanation clears loading notices with saved=$saved and earlierNotice=$earlierNotice',
        (tester) async {
          final settings = SettingsViewModel();
          final favourites = SavedFavourites();
          addTearDown(settings.dispose);
          addTearDown(favourites.dispose);
          late BuildContext context;
          final response = Completer<http.Response>();
          final requested = Completer<void>();
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(value: settings),
                    ChangeNotifierProvider<FavouritesViewModel>.value(
                      value: favourites,
                    ),
                  ],
                  child: MaterialApp(
                    home: Scaffold(
                      body: Builder(
                        builder: (value) {
                          context = value;
                          return saved
                              ? const FavouritesView()
                              : HadithCard(
                                  hadith: hadith,
                                  isFavourite: false,
                                  onFavouriteToggle: () async {},
                                );
                        },
                      ),
                    ),
                  ),
                ),
              );
              if (earlierNotice) {
                showAppSnackBar(
                  context,
                  const SnackBar(content: Text('Earlier notice')),
                );
              }
              await tester.pumpAndSettle();
              await tester.tap(find.text('الشرح'));
              await tester.tap(find.text('الشرح'));
              for (var i = 0; i < 100 && !requested.isCompleted; i++) {
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 10)),
                );
                await tester.pump();
              }
              expect(requested.isCompleted, isTrue);
              response.complete(
                http.Response(
                  jsonEncode({
                    'data': {
                      'sharhMetadata': {'sharh': 'Explanation content'},
                    },
                  }),
                  200,
                ),
              );
              for (
                var i = 0;
                i < 100 && find.text('Explanation content').evaluate().isEmpty;
                i++
              ) {
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 10)),
                );
                await tester.pump();
              }
              await tester.pumpAndSettle();
              expect(find.text('Explanation content'), findsOneWidget);
              expect(find.text('جارٍ البحث عن الشرح...'), findsNothing);
              expect(find.byType(SnackBar), findsNothing);
            },
            () => MockClient((_) {
              requested.complete();
              return response.future;
            }),
          );
        },
      );
    }
  }
}
