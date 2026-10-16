import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/services/filter_catalog_service.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';
import 'package:hadithsearcher/views/welcome/welcome_view.dart';
import 'telemetry/fake_backend.dart';
import 'fixtures/search_catalogs.dart';

http.Response catalog(String code) => http.Response(
  jsonEncode({
    'data': [
      {'key': code, 'value': 'API option $code'},
    ],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'preload is sequential, deduplicated, and reuses fresh disk caches',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      final paths = <String>[];
      var active = 0;
      var peak = 0;
      await http.runWithClient(
        () async {
          final first = vm.preloadCatalogs();
          await Future.wait([first, vm.preloadCatalogs()]);
          expect(paths, [
            '/v1/data/methodSearch',
            '/v1/data/zoneSearch',
            '/v1/data/degree',
            '/v1/data/mohdith',
            '/v1/data/book',
            '/v1/data/rawi',
          ]);
          expect(peak, 1);
          expect(vm.searchWays.last.apiCode, 'server-method');
          expect(vm.searchRanges.last.apiCode, 'server-range');
          final grades = await vm.loadFilterOptions(SearchFilter.grade);
          expect(grades.data!.single.apiCode, 'server-grade');
          expect(paths, hasLength(6));
          final restarted = SearchViewModel();
          addTearDown(restarted.dispose);
          await restarted.preloadCatalogs();
          expect(restarted.searchWays.last.apiCode, 'server-method');
          expect(paths, hasLength(6));
          vm.setSearchWay(vm.searchWays.last);
          vm.setSearchRange(vm.searchRanges.last);
          await vm.saveAdvancedPrefs();
          final restored = SearchViewModel();
          addTearDown(restored.dispose);
          await restored.init();
          final params = SearchParams(
            keyword: 'query',
            searchWay: restored.searchWay,
            searchRange: restored.searchRange,
          );
          expect(params.toQueryParams()['st'], 'server-method');
          expect(params.toQueryParams()['t'], 'server-range');
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          active++;
          if (active > peak) peak = active;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          active--;
          return catalog(switch (request.url.pathSegments.last) {
            'methodSearch' => 'server-method',
            'zoneSearch' => 'server-range',
            'degree' => 'server-grade',
            _ => 'server-id',
          });
        }),
      );
    },
  );

  test('on-demand and preload requests share one in-flight catalog', () async {
    final service = FilterCatalogService();
    final response = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(
      () async {
        final background = service.loadCatalog('degree');
        final picker = service.load(SearchFilter.grade);
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
        response.complete(catalog('api-grade'));
        for (final result in await Future.wait([background, picker])) {
          expect(result.data!.single.apiCode, 'api-grade');
        }
      },
      () => MockClient((_) {
        calls++;
        return response.future;
      }),
    );
  });

  test(
    'stale catalogs remain usable offline and failures can be retried',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'filterCatalog.degree',
        SearchOption.encodeCatalog([const SearchOption('old-grade', 'Cached')]),
      );
      await prefs.setInt('filterCatalog.degree.savedAt', 0);
      final service = FilterCatalogService();
      var calls = 0;
      await http.runWithClient(
        () async {
          final offline = await service.load(SearchFilter.grade);
          expect(offline.data!.single.apiCode, 'old-grade');
          final retried = await service.load(SearchFilter.grade);
          expect(retried.data!.single.apiCode, 'new-grade');
          expect(calls, 2);
        },
        () => MockClient(
          (_) async =>
              ++calls == 1 ? http.Response('', 503) : catalog('new-grade'),
        ),
      );
    },
  );

  test('disposing during preload stops subsequent catalog requests', () async {
    final vm = SearchViewModel();
    final response = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(
      () async {
        final preload = vm.preloadCatalogs();
        await Future<void>.delayed(Duration.zero);
        vm.dispose();
        response.complete(catalog('a'));
        await preload;
        expect(calls, 1);
      },
      () => MockClient((_) {
        calls++;
        return response.future;
      }),
    );
  });

  test('offline preload stops instead of retrying every endpoint', () async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    var calls = 0;
    await http.runWithClient(
      () async {
        await vm.preloadCatalogs();
        expect(calls, 1);
        expect(vm.searchWays, [SearchWay.anyWord]);
        expect(vm.searchRanges, [SearchRange.all]);
      },
      () => MockClient((_) async {
        calls++;
        throw http.ClientException('offline');
      }),
    );
  });

  testWidgets('welcome renders while startup catalog request is pending', (
    tester,
  ) async {
    final telemetry = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: FakeBackend(),
    );
    addTearDown(telemetry.dispose);
    final response = Completer<http.Response>();
    var calls = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          HadithSearcherApp(
            initialThemeMode: ThemeMode.light,
            telemetry: telemetry,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WelcomeView), findsOneWidget);
        expect(calls, 1);
        final vm = tester
            .element(find.byType(MaterialApp))
            .read<SearchViewModel>();
        final preload = vm.preloadCatalogs();
        await tester.pumpWidget(const SizedBox());
        response.complete(catalog('a'));
        await finishCatalogPreload(tester, preload);
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((_) {
        calls++;
        return response.future;
      }),
    );
  });
}
