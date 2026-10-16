import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';

const excluded = [SearchOption('1', 'one'), SearchOption('2', 'two')];
http.Response response({
  bool empty = false,
  bool next = false,
  bool applied = true,
  String id = 'kept',
}) => http.Response(
  jsonEncode({
    'metadata': {'hasNextPage': next, if (applied) 'exclusionsApplied': true},
    'data': [
      if (!empty) {'hadithId': id, 'hadith': 'text'},
    ],
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'compact exclusions persist and pagination keeps the original snapshot',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      vm.setSelectedOptions(SearchFilter.narrator, [
        SearchOption.allNarrators,
      ], excluded: excluded);
      await vm.saveAdvancedPrefs();
      final restarted = SearchViewModel();
      addTearDown(restarted.dispose);
      await restarted.init();
      expect(
        restarted
            .excludedOptions(SearchFilter.narrator)
            .map((option) => option.apiCode),
        ['1', '2'],
      );
      expect(restarted.activeFilters, hasLength(1));
      expect(
        restarted.selectionLabel(SearchFilter.narrator),
        contains('باستثناء'),
      );
      var requests = 0;
      await http.runWithClient(
        () async {
          await restarted.search('query');
          restarted.resetFilters();
          await restarted.loadMore();
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.queryParametersAll['rawi[]'], ['0']);
          expect(request.url.queryParametersAll['xrawi[]'], ['1', '2']);
          expect(request.url.toString().length, lessThan(500));
          return response(next: requests == 1, id: '$requests');
        }),
      );
      expect(requests, 2);
      await restarted.setSaveAdvancedSettings(false);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'searchFilterExclusions',
        ),
        isFalse,
      );
    },
  );

  test('empty excluded pages are skipped without losing later pages', () async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    vm.setSelectedOptions(SearchFilter.narrator, [
      SearchOption.allNarrators,
    ], excluded: excluded);
    final pages = <int>[];
    await http.runWithClient(
      () async {
        await vm.search('query');
        expect(vm.results.single.id, '2');
        expect(vm.errorMessage, isNull);
        await vm.loadMore();
        expect(vm.results.map((hadith) => hadith.id), ['2', '4']);
        expect(vm.hasMoreResults, isFalse);
      },
      () => MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        pages.add(page);
        return response(empty: page.isOdd, next: page < 4, id: '$page');
      }),
    );
    expect(pages, [1, 2, 3, 4]);
  });

  test('a changed search cancels the old empty-page traversal', () async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    vm.setSelectedOptions(SearchFilter.narrator, [
      SearchOption.allNarrators,
    ], excluded: excluded);
    final old = Completer<http.Response>();
    final started = Completer<void>();
    final queries = <String>[];
    await http.runWithClient(
      () async {
        final previous = vm.search('old');
        await started.future;
        await vm.search('new');
        old.complete(response(empty: true, next: true));
        await previous;
        expect(vm.results.single.id, 'new');
      },
      () => MockClient((request) {
        final query = request.url.queryParameters['value']!;
        queries.add(query);
        if (query == 'old') {
          started.complete();
          return old.future;
        }
        return Future.value(response(id: 'new'));
      }),
    );
    expect(queries, ['old', 'new']);
  });

  test('an older API cannot silently ignore exclusions', () async {
    final result = await http.runWithClient(
      () => ApiService().searchHadith(
        SearchParams(
          keyword: 'query',
          exclusions: {SearchFilter.narrator: excluded},
        ),
      ),
      () => MockClient((_) async => response(applied: false)),
    );
    expect(result.error, ApiError.unsupportedFilters);
    expect(result.data, isNull);
  });

  test(
    'legacy nearly-full selections compact before their first request',
    () async {
      final catalog = List.generate(
        1000,
        (index) => SearchOption('${index + 1}', 'narrator $index'),
      );
      SharedPreferences.setMockInitialValues({
        'searchFilters': jsonEncode({
          'narrator': catalog.skip(2).map((option) => option.toJson()).toList(),
        }),
      });
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await http.runWithClient(
        () => vm.search('query'),
        () => MockClient((request) async {
          if (request.url.path == '/v1/data/rawi') {
            return http.Response(
              jsonEncode({
                'data': catalog.map((option) => option.toJson()).toList(),
              }),
              200,
            );
          }
          expect(request.url.queryParametersAll['xrawi[]'], ['1', '2']);
          expect(request.url.toString().length, lessThan(500));
          return response();
        }),
      );
      expect(vm.errorMessage, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('searchFilters')!.length, lessThan(500));
      expect(prefs.getString('searchFilterExclusions')!.length, lessThan(500));
    },
  );
}
