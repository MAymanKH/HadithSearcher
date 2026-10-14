import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/services/filter_catalog_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';

http.Response catalogResponse(String label, {bool wrapped = true}) {
  final data = [
    {'key': '0', 'value': 'الجميع'},
    {'key': '999', 'value': label},
  ];
  return http.Response(
    jsonEncode(wrapped ? {'status': 'success', 'data': data} : data),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('startup does not fetch or decode any catalog', () async {
    SharedPreferences.setMockInitialValues({
      'filterCatalog.rawi': 'invalid cached JSON',
      'searchRawi': '999',
      'searchRawi.label': 'راوٍ محفوظ',
    });
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    await http.runWithClient(
      vm.init,
      () => MockClient((request) async {
        fail('Startup requested ${request.url}');
      }),
    );
    expect(vm.searchRawi.apiCode, '999');
    expect(vm.searchRawi.arabicName, 'راوٍ محفوظ');
  });

  for (final wrapped in [true, false]) {
    test(
      'catalog parser accepts ${wrapped ? 'wrapped' : 'bare'} data',
      () async {
        final result = await http.runWithClient(
          () => ApiService().getFilterOptions('book'),
          () => MockClient(
            (_) async => catalogResponse('كتاب آخر', wrapped: wrapped),
          ),
        );
        expect(result.isSuccess, isTrue);
        expect(result.data!.last.arabicName, 'كتاب آخر');
      },
    );
  }

  test('each catalog loads on demand and is reused across restarts', () async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    await vm.init();
    final requests = <String>[];
    await http.runWithClient(
      () async {
        final books = await vm.loadFilterOptions(SearchFilter.book);
        expect(requests, ['/v1/data/book']);
        vm.setSearchBook(books.data!.last);
        final scholars = await vm.loadFilterOptions(SearchFilter.scholar);
        vm.setSearchMohdith(scholars.data!.last);
        final narrators = await vm.loadFilterOptions(SearchFilter.narrator);
        vm.setSearchRawi(narrators.data!.last);
        await vm.loadFilterOptions(SearchFilter.narrator);
        expect(requests, [
          '/v1/data/book',
          '/v1/data/mohdith',
          '/v1/data/rawi',
        ]);
        await vm.saveAdvancedPrefs();
      },
      () => MockClient((request) async {
        requests.add(request.url.path);
        return catalogResponse('اختيار ${request.url.path}');
      }),
    );
    final restored = SearchViewModel();
    addTearDown(restored.dispose);
    await restored.init();
    expect(restored.searchBook.apiCode, '999');
    expect(restored.searchMohdith.apiCode, '999');
    expect(restored.searchRawi.apiCode, '999');
    await http.runWithClient(
      () async {
        for (final filter in SearchFilter.values) {
          final result = await restored.loadFilterOptions(filter);
          expect(result.data!.last.apiCode, '999');
          expect(result.data!.first.arabicName, filter.all.arabicName);
        }
      },
      () =>
          MockClient((_) async => throw StateError('Fresh cache used network')),
    );
  });

  test(
    'concurrent requests share one fetch and failures can be retried',
    () async {
      final catalogs = FilterCatalogService();
      final response = Completer<http.Response>();
      var calls = 0;
      await http.runWithClient(
        () async {
          final first = catalogs.load(SearchFilter.narrator);
          final second = catalogs.load(SearchFilter.narrator);
          expect(identical(first, second), isTrue);
          response.complete(http.Response('unavailable', 503));
          expect((await first).isError, isTrue);
          expect((await second).isError, isTrue);
          expect(
            (await catalogs.load(SearchFilter.narrator)).data!.last.apiCode,
            '999',
          );
          expect(calls, 2);
        },
        () => MockClient((_) {
          calls++;
          return calls == 1
              ? response.future
              : Future.value(catalogResponse('راوٍ آخر'));
        }),
      );
    },
  );

  test('stale cache works offline and refreshes on the next opening', () async {
    SharedPreferences.setMockInitialValues({
      'filterCatalog.book': jsonEncode([
        {'key': '999', 'value': 'كتاب محفوظ'},
      ]),
      'filterCatalog.book.savedAt': 0,
    });
    final catalogs = FilterCatalogService();
    var calls = 0;
    await http.runWithClient(
      () async {
        expect(
          (await catalogs.load(SearchFilter.book)).data!.last.arabicName,
          'كتاب محفوظ',
        );
        expect(
          (await catalogs.load(SearchFilter.book)).data!.last.arabicName,
          'كتاب محدث',
        );
        expect(calls, 2);
      },
      () => MockClient(
        (_) async => ++calls == 1
            ? http.Response('offline', 503)
            : catalogResponse('كتاب محدث'),
      ),
    );
  });

  test('invalid cached and empty remote catalogs remain retryable', () async {
    SharedPreferences.setMockInitialValues({
      'filterCatalog.rawi': '{"data":null}',
    });
    final catalogs = FilterCatalogService();
    var calls = 0;
    await http.runWithClient(
      () async {
        expect((await catalogs.load(SearchFilter.narrator)).isError, isTrue);
        expect((await catalogs.load(SearchFilter.narrator)).isSuccess, isTrue);
        expect(calls, 2);
      },
      () => MockClient(
        (_) async => ++calls == 1
            ? http.Response('{"data":[]}', 200)
            : catalogResponse('راوٍ آخر'),
      ),
    );
  });

  test('legacy labels keep their IDs without loading a catalog', () async {
    SharedPreferences.setMockInitialValues({
      'searchBook': 'صحيح البخاري',
      'searchMohdith': 'الإمام المالك',
      'filterCatalog.book': jsonEncode([
        {'key': '0', 'value': 'الجميع'},
        {'key': '6216', 'value': 'الجامع الصحيح'},
      ]),
    });
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    await vm.init();
    expect(vm.searchBook.apiCode, '6216');
    expect(vm.searchMohdith.apiCode, '179');
    vm.resetFilters();
    expect(vm.activeFilters, isEmpty);
    expect(vm.searchBook, SearchOption.allBooks);
  });

  test('narrator is sent on every search page and reset removes it', () async {
    const narrator = SearchOption('8918', 'عمر بن الخطاب');
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    await vm.init();
    vm.toggleAdvancedSearch();
    expect(vm.hasSettingsChanged(), isFalse);
    vm.setSearchRawi(narrator);
    expect(vm.hasSettingsChanged(), isTrue);
    expect(vm.activeFilters, contains(narrator.arabicName));
    final pages = <String>[];
    await http.runWithClient(
      () async {
        await vm.search('العمل');
        await vm.loadMore();
      },
      () => MockClient((request) async {
        final query = request.url.queryParameters;
        expect(query['rawi[]'], '8918');
        pages.add(query['page']!);
        return http.Response(
          jsonEncode({
            'metadata': {'hasNextPage': query['page'] == '1'},
            'data': [
              {'hadithId': 'page-${query['page']}', 'hadith': 'text'},
            ],
          }),
          200,
        );
      }),
    );
    expect(pages, ['1', '2']);
    final params = const SearchParams(
      keyword: 'العمل',
      searchRawi: narrator,
    ).nextPage().resetPage();
    expect(params.toQueryParams()['rawi[]'], '8918');
    expect(params.toQueryString(), contains('&rawi[]=8918'));
    vm.resetFilters();
    expect(vm.searchRawi, SearchOption.allNarrators);
    expect(vm.activeFilters, isEmpty);
    vm.setSearchRawi(narrator);
    await vm.saveAdvancedPrefs();
    await vm.setSaveAdvancedSettings(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('searchRawi'), isFalse);
    expect(prefs.containsKey('searchRawi.label'), isFalse);
  });
}
