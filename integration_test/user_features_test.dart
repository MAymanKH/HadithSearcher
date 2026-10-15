import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'package:hadithsearcher/services/explanation_service.dart';
import 'package:hadithsearcher/services/favourite_details_service.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import '../test/telemetry/fake_backend.dart';

http.Response jsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'upgrade preserves favourites; undo and explanations work offline',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      await preferences.setBool('welcomeCompleted', true);
      final path = join(await getDatabasesPath(), 'hadithsearcher.db');
      await deleteDatabase(path);
      final legacy = await openDatabase(
        path,
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE favourites (id INTEGER PRIMARY KEY AUTOINCREMENT, hadithtext TEXT NOT NULL, hadithinfo TEXT NOT NULL, hadithid TEXT NOT NULL UNIQUE)',
          );
          await db.insert('favourites', {
            'hadithtext': 'legacy text',
            'hadithinfo': 'legacy citation',
            'hadithid': 'legacy',
          });
        },
      );
      await legacy.close();
      final db = DatabaseService();
      final migrated = await db.getFavourite('legacy');
      expect(migrated!.hadithText, 'legacy text');
      expect(migrated.explanation, isNull);
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      const hadith = Hadith(
        id: 'offline-test',
        text: 'Saved test hadith',
        rawi: 'narrator',
        mohdith: 'scholar',
        book: 'book',
        numberOrPage: '1',
        grade: 'grade',
        hasSharhMetadata: true,
        sharhId: '123',
        hasAlternateHadithSahih: true,
      );
      await tester.runAsync(
        () => http.runWithClient(
          () async {
            expect(
              await vm
                  .toggleFavourite(hadith)
                  .timeout(const Duration(seconds: 15)),
              isNull,
            );
            await FavouriteDetailsService().saveOffline(hadith);
            final explanation = await ExplanationService()
                .getExplanation(hadith.id, sharhId: '123')
                .timeout(const Duration(seconds: 15));
            expect(explanation.data, 'Saved explanation');
          },
          () => MockClient((request) async {
            if (request.url.path == '/v1/site/hadith/offline-test') {
              return jsonResponse({'data': hadith.toJson()});
            }
            expect(request.url.path, '/v1/site/sharh/123');
            return jsonResponse({
              'data': {
                'sharhMetadata': {'sharh': 'Saved explanation'},
              },
            });
          }),
        ),
      );
      final saved = await db.getFavourite(hadith.id);
      expect(saved!.explanation, 'Saved explanation');
      expect(saved.hasAlternate, isTrue);
      final telemetry = TelemetryService(
        preferences: preferences,
        backend: FakeBackend(),
      );
      await telemetry.save(diagnostics: false, analytics: false);
      addTearDown(telemetry.dispose);
      var networkRequests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            HadithSearcherApp(
              initialThemeMode: ThemeMode.light,
              telemetry: telemetry,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('المفضلة').last);
          await tester.pumpAndSettle();
          final remove = find.widgetWithText(TextButton, 'المفضلة').first;
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(await db.getFavourite(hadith.id), isNull);
          await tester.tap(find.text('تراجع'));
          await tester.pumpAndSettle();
          final restored = await db.getFavourite(hadith.id);
          expect(restored!.id, saved.id);
          expect(restored.explanation, 'Saved explanation');
          expect((await db.getFavourites()).first.hadithId, hadith.id);
          expect(vm.isFavourite(hadith.id), isTrue);
          networkRequests = 0;
          await tester.tap(find.widgetWithText(TextButton, 'الشرح').first);
          await tester.pumpAndSettle();
          expect(find.text('Saved explanation'), findsOneWidget);
          expect(networkRequests, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          networkRequests++;
          throw http.ClientException('offline', request.url);
        }),
      );
    },
  );
}
