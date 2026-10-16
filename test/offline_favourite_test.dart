import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hadithsearcher/models/hadith.dart';
import 'package:hadithsearcher/services/database_service.dart';
import 'package:hadithsearcher/services/explanation_service.dart';
import 'package:hadithsearcher/services/favourite_details_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';

const hadith = Hadith(
  id: 'saved',
  text: 'حديث محفوظ',
  rawi: 'راو',
  mohdith: 'محدث',
  book: 'كتاب',
  numberOrPage: '1',
  grade: 'صحيح',
  takhrij: 'تخريج محفوظ',
  explainGrade: 'حكم مفصل',
  hasUsulHadith: true,
  hasSharhMetadata: true,
  hasSimilarHadith: true,
  sharhId: 'explanation',
);

http.Response response(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  late Directory directory;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    directory = await Directory.systemTemp.createTemp('hadith-offline-');
    await databaseFactory.setDatabasesPath(directory.path);
    final legacy = await openDatabase(
      join(directory.path, 'hadithsearcher.db'),
      version: 3,
      onCreate: (database, _) async {
        await database.execute(
          'CREATE TABLE favourites (id INTEGER PRIMARY KEY AUTOINCREMENT, hadithtext TEXT NOT NULL, hadithinfo TEXT NOT NULL, hadithid TEXT NOT NULL UNIQUE, sharhid TEXT, explanation TEXT, hasalternate INTEGER NOT NULL DEFAULT 0)',
        );
        await database.insert('favourites', {
          'hadithtext': 'legacy',
          'hadithinfo': 'citation',
          'hadithid': 'legacy',
          'explanation': 'old explanation',
        });
      },
    );
    await legacy.close();
    await db.database;
  });
  tearDownAll(() async {
    await (await db.database).close();
    await directory.delete(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('schema upgrade keeps legacy favourites and explanations', () async {
    final legacy = await db.getFavourite('legacy');
    expect(legacy!.hadithText, 'legacy');
    expect(legacy.explanation, 'old explanation');
    expect(legacy.details, isNull);
    expect(legacy.origins, isNull);
  });

  test(
    'favouriting downloads full details, origins and explanation for offline use and undo',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      final paths = <String>[];
      await http.runWithClient(
        () async {
          expect(await vm.toggleFavourite(hadith), isNull);
          await FavouriteDetailsService().saveOffline(hadith);
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.contains('/usul/')) {
            return response({
              'data': {
                'usulHadith': {
                  'sources': [
                    {
                      'source': 'مصدر محفوظ',
                      'chain': 'إسناد محفوظ',
                      'hadithText': 'متن محفوظ',
                    },
                  ],
                },
              },
            });
          }
          if (request.url.path.contains('/sharh/')) {
            return response({
              'data': {
                'sharhMetadata': {'sharh': 'شرح محفوظ'},
              },
            });
          }
          return response({'data': hadith.toJson()});
        }),
      );
      expect(paths, [
        '/v1/site/hadith/saved',
        '/v1/site/hadith/usul/saved',
        '/v1/site/sharh/explanation',
      ]);
      final saved = (await db.getFavourite(hadith.id))!;
      expect(saved.details!.takhrij, hadith.takhrij);
      expect(saved.details!.explainGrade, hadith.explainGrade);
      expect(saved.hasSimilarHadith, isTrue);
      expect(saved.hasExplanation, isTrue);
      expect(saved.explanation, 'شرح محفوظ');
      expect(saved.origins!.sources.single.chain, 'إسناد محفوظ');
      await db.removeFavourite(hadith.id);
      await db.restoreFavourite(saved);
      await http.runWithClient(
        () async {
          final details = await FavouriteDetailsService().getSavedDetails(
            hadith.id,
          );
          final origins = await FavouriteDetailsService().getOrigins(hadith.id);
          final explanation = await ExplanationService().getExplanation(
            hadith.id,
          );
          expect(details.data!.takhrij, hadith.takhrij);
          expect(origins.data!.sources.single.text, 'متن محفوظ');
          expect(explanation.data, 'شرح محفوظ');
          final restored = (await db.getFavourite(hadith.id))!;
          expect(restored.hasSimilarHadith, isTrue);
          expect(restored.hasExplanation, isTrue);
        },
        () => MockClient(
          (_) async => throw StateError('Offline read used network'),
        ),
      );
    },
  );

  for (final available in [false, true]) {
    test(
      'availability and returned explanation survive offline saving: $available',
      () async {
        final item = Hadith.fromJson({
          ...hadith.toJson(),
          'hadithId': 'availability-$available',
          'hasUsulHadith': false,
          'hasSimilarHadith': available,
          'hasSharhMetadata': available,
          'sharhMetadata': available
              ? {
                  'id': 'inline',
                  'isContainSharh': true,
                  'sharh': 'شرح من نتائج البحث',
                }
              : null,
        });
        await db.addFavourite(
          hadithId: item.id,
          hadithText: item.text,
          hadithInfo: item.formattedInfo,
          hadith: item,
          sharhId: item.sharhId,
        );
        final initial = (await db.getFavourite(item.id))!;
        expect(initial.hasSimilarHadith, available);
        expect(initial.hasExplanation, available);
        expect(initial.details!.explanation, item.explanation);
        expect(initial.explanation, item.explanation);

        final paths = <String>[];
        await http.runWithClient(
          () => FavouriteDetailsService().saveOffline(item),
          () => MockClient((request) async {
            paths.add(request.url.path);
            // The full metadata response need not repeat the explanation text.
            return response({
              'data': {
                ...item.toJson(),
                'sharhMetadata': available ? {'id': 'inline'} : null,
              },
            });
          }),
        );
        expect(paths, ['/v1/site/hadith/${item.id}']);
        final saved = (await db.getFavourite(item.id))!;
        expect(saved.hasSimilarHadith, available);
        expect(saved.hasExplanation, available);
        expect(saved.explanation, item.explanation);
        await db.removeFavourite(item.id);
        await db.restoreFavourite(saved);
        await http.runWithClient(
          () async {
            final restored = (await db.getFavourite(item.id))!;
            expect(restored.hasSimilarHadith, available);
            expect(restored.hasExplanation, available);
            if (available) {
              expect(
                (await ExplanationService().getExplanation(item.id)).data,
                item.explanation,
              );
            }
          },
          () => MockClient(
            (_) async => throw StateError('Offline read used network'),
          ),
        );
      },
    );
  }

  test(
    'snapshot explanation opens offline before background downloads finish',
    () async {
      final item = Hadith.fromJson({
        ...hadith.toJson(),
        'hadithId': 'snapshot-only',
        'sharhMetadata': {
          'isContainSharh': true,
          'sharh': 'شرح محفوظ مع النتائج',
        },
      });
      await db.addFavourite(
        hadithId: item.id,
        hadithText: item.text,
        hadithInfo: item.formattedInfo,
      );
      await db.saveDetails(item);
      await http.runWithClient(
        () async {
          final saved = (await db.getFavourite(item.id))!;
          expect(saved.sharhId, isNull);
          expect(saved.explanation, isNull);
          expect(saved.hasExplanation, isTrue);
          expect(
            (await ExplanationService().getExplanation(item.id)).data,
            item.explanation,
          );
        },
        () => MockClient(
          (_) async =>
              throw StateError('Returned explanation was downloaded again'),
        ),
      );
      final cached = (await db.getFavourite(item.id))!;
      expect(cached.explanation, item.explanation);
    },
  );

  test(
    'offline downloads are deduplicated, serialized and skip removed favourites',
    () async {
      for (final id in ['one', 'two', 'removed']) {
        await db.addFavourite(
          hadithId: id,
          hadithText: 'text',
          hadithInfo: 'citation',
        );
      }
      final firstResponse = Completer<http.Response>();
      final started = Completer<void>();
      final paths = <String>[];
      await http.runWithClient(
        () async {
          Hadith item(String id) => Hadith.fromJson({
            ...hadith.toJson(),
            'hadithId': id,
            'hasUsulHadith': false,
            'hasSharhMetadata': false,
            'sharhMetadata': null,
          });
          final first = FavouriteDetailsService().saveOffline(item('one'));
          final duplicate = FavouriteDetailsService().saveOffline(item('one'));
          final second = FavouriteDetailsService().saveOffline(item('two'));
          final removed = FavouriteDetailsService().saveOffline(
            item('removed'),
          );
          await started.future;
          expect(paths, ['/v1/site/hadith/one']);
          await db.removeFavourite('removed');
          firstResponse.complete(response({'data': item('one').toJson()}));
          await Future.wait([first, duplicate, second, removed]);
          expect(paths, ['/v1/site/hadith/one', '/v1/site/hadith/two']);
          expect(await db.getFavourite('removed'), isNull);
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/one')) {
            started.complete();
            return firstResponse.future;
          }
          return response({
            'data': {'hadithId': 'two'},
          });
        }),
      );
    },
  );
}
