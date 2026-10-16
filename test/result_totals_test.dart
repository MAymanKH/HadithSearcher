import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/app_localizations.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/viewmodels/settings_viewmodel.dart';
import 'package:hadithsearcher/views/search/search_view.dart';

http.Response page(Map<String, Object> metadata, {String id = 'result'}) =>
    http.Response(
      jsonEncode({
        'metadata': {'hasNextPage': false, ...metadata},
        'data': [
          {
            'hadithId': id,
            'hadith': 'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
            'rawi': 'عمر بن الخطاب',
            'mohdith': 'البخاري',
            'book': 'صحيح البخاري',
            'numberOrPage': '1',
            'grade': 'صحيح',
            'bookId': '6216',
            'mohdithId': '256',
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
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

  test('totals follow the requested mode and survive pagination', () async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    await http.runWithClient(
      () async {
        await vm.search('النيات');
        expect(vm.resultTotal, 1234);
        await vm.loadMore();
        expect(vm.resultTotal, 1234);
        vm.setSpecialist(true);
        expect(vm.resultTotal, isNull);
        await vm.search('النيات');
        expect(vm.resultTotal, 8765);
      },
      () => MockClient((request) async {
        final query = request.url.queryParameters;
        if (query['page'] == '2') return page({});
        return page({
          'hasNextPage': true,
          'numberOfNonSpecialist': 1234,
          'numberOfSpecialist': 8765,
          'total': 99999,
        });
      }),
    );
  });

  test(
    'unknown totals and exclusions never show a page count as a total',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await http.runWithClient(
        () async {
          await vm.search('total');
          expect(vm.resultTotal, 12);
          await vm.search('missing');
          expect(vm.resultTotal, isNull);
          vm.setSelectedOptions(
            SearchFilter.book,
            [SearchFilter.book.all],
            excluded: [const SearchOption('1', 'كتاب')],
          );
          await vm.search('excluded');
          expect(vm.resultTotal, isNull);
        },
        () => MockClient((request) async {
          final keyword = request.url.queryParameters['value'];
          return page(
            keyword == 'missing'
                ? {'length': 1, 'currentPageCount': 1}
                : {'total': 12, 'exclusionsApplied': true},
          );
        }),
      );
    },
  );

  test(
    'new, failed, and shared searches clear totals and reject stale responses',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      final old = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await vm.search('first');
          expect(vm.resultTotal, 12);
          final pending = vm.search('old');
          expect(vm.resultTotal, isNull);
          await vm.search('new');
          old.complete(page({'total': 90}));
          await pending;
          expect(vm.resultTotal, 12);
          await vm.search('failure');
          expect(vm.resultTotal, isNull);
          await vm.search('first');
          vm.prepareSharedSearch('shared', 1);
          expect(vm.resultTotal, isNull);
        },
        () => MockClient((request) async {
          final keyword = request.url.queryParameters['value'];
          if (keyword == 'old') return old.future;
          if (keyword == 'failure') return http.Response('error', 503);
          return page({'total': 12});
        }),
      );
    },
  );

  for (final locale in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'compact total fits the $locale ${dark ? 'dark' : 'light'} toolbar',
        (tester) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final vm = SearchViewModel();
          final settings = SettingsViewModel();
          await settings.setFontFamily('Cairo');
          addTearDown(vm.dispose);
          addTearDown(settings.dispose);
          await http.runWithClient(
            () async {
              await tester.pumpWidget(
                RepaintBoundary(
                  key: const Key('capture'),
                  child: MultiProvider(
                    providers: [
                      ChangeNotifierProvider.value(value: settings),
                      ChangeNotifierProvider.value(value: vm),
                    ],
                    child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      locale: Locale(locale),
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      supportedLocales: AppLocalizations.supportedLocales,
                      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                      home: const SearchView(),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
              final toolbarHeight = tester.getSize(find.byType(AppBar)).height;
              final l = AppLocalizations.of(
                tester.element(find.byType(SearchView)),
              );
              expect(
                find.byKey(const ValueKey('search-result-total')),
                findsNothing,
              );
              await vm.search('النيات');
              await tester.pumpAndSettle();
              expect(find.text(l.resultCount(1234)), findsOneWidget);
              expect(find.text(l.resultCount(8765)), findsNothing);
              expect(tester.getTopLeft(find.byType(TextField)).dy, fieldTop);
              expect(tester.getSize(find.byType(AppBar)).height, toolbarHeight);
              final total = find.byKey(const ValueKey('search-result-total'));
              expect(
                tester
                    .getRect(find.byType(AppBar))
                    .contains(tester.getCenter(total)),
                isTrue,
              );

              if (const bool.fromEnvironment('CAPTURE_SEARCH_UI')) {
                await tester.pump(const Duration(seconds: 1));
                await tester.pumpAndSettle();
                await tester.runAsync(() async {
                  final boundary = tester.renderObject<RenderRepaintBoundary>(
                    find.byKey(const Key('capture')),
                  );
                  final picture = await boundary.toImage(pixelRatio: 2);
                  final bytes = await picture.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final directory = Directory('build/search-ui')
                    ..createSync(recursive: true);
                  await File(
                    '${directory.path}/$locale-${dark ? 'dark' : 'light'}.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                  picture.dispose();
                });
              }

              vm.toggleAdvancedSearch();
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('search-result-total')),
                findsNothing,
              );
              vm.setSpecialist(true);
              vm.closeAdvancedSearch();
              await vm.search('النيات');
              await tester.pumpAndSettle();
              expect(find.text(l.resultCount(8765)), findsOneWidget);
              expect(find.text(l.resultCount(1234)), findsNothing);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            },
            () => MockClient(
              (_) async => page({
                'numberOfNonSpecialist': 1234,
                'numberOfSpecialist': 8765,
              }),
            ),
          );
        },
      );
    }
  }
}
