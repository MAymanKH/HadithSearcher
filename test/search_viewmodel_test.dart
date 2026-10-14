import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';

http.Response page(String prefix, {int count = 2, bool hasNext = false}) =>
    http.Response(
      jsonEncode({
        'metadata': {'length': count, 'hasNextPage': hasNext},
        'data': List.generate(
          count,
          (i) => {'hadithId': '$prefix-$i', 'hadith': prefix},
        ),
      }),
      200,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a failed page retries once, then skips silently on the next load',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      final pages = <String>[];
      await http.runWithClient(
        () async {
          await vm.search('query');
          await vm.loadMore();
          expect(pages, ['1', '2', '2']);
          expect(vm.errorMessage, isNull);
          expect(vm.hasMoreResults, isTrue);
          await vm.loadMore();
          expect(pages, ['1', '2', '2', '3']);
          expect(vm.results.last.id, 'page3-1');
          expect(vm.hasMoreResults, isFalse);
        },
        () => MockClient((request) async {
          final number = request.url.queryParameters['page']!;
          pages.add(number);
          return number == '2'
              ? http.Response('unavailable', 503)
              : page('page$number', hasNext: number == '1');
        }),
      );
    },
  );

  test('a successful retry appends the page exactly once', () async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    var attempts = 0;
    await http.runWithClient(
      () async {
        await vm.search('query');
        await vm.loadMore();
      },
      () => MockClient((request) async {
        if (request.url.queryParameters['page'] == '1')
          return page('first', hasNext: true);
        return ++attempts == 1 ? http.Response('error', 500) : page('second');
      }),
    );
    expect(attempts, 2);
    expect(vm.results.map((h) => h.id), [
      'first-0',
      'first-1',
      'second-0',
      'second-1',
    ]);
  });

  test(
    'old pagination cannot append, retry, or clear the new search loading flag',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      final oldResponse = Completer<http.Response>();
      final newResponse = Completer<http.Response>();
      var oldPageRequests = 0;
      await http.runWithClient(
        () async {
          await vm.search('old');
          final oldLoad = vm.loadMore();
          final newSearch = vm.search('new');
          oldResponse.complete(http.Response('error', 500));
          await oldLoad;
          expect(vm.isLoading, isTrue);
          expect(vm.results, isEmpty);
          newResponse.complete(page('new'));
          await newSearch;
        },
        () => MockClient((request) async {
          final q = request.url.queryParameters;
          if (q['value'] == 'new') return newResponse.future;
          if (q['page'] == '2') {
            oldPageRequests++;
            return oldResponse.future;
          }
          return page('old', hasNext: true);
        }),
      );
      expect(oldPageRequests, 1);
      expect(vm.results.every((h) => h.id.startsWith('new')), isTrue);
    },
  );

  test('a delayed first page cannot replace a newer search', () async {
    final vm = SearchViewModel();
    addTearDown(vm.dispose);
    final old = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final firstSearch = vm.search('old');
        await vm.search('new');
        old.complete(page('old', hasNext: true));
        await firstSearch;
      },
      () => MockClient(
        (request) async => request.url.queryParameters['value'] == 'old'
            ? old.future
            : page('new'),
      ),
    );
    expect(vm.results.first.id, 'new-0');
    expect(vm.hasMoreResults, isFalse);
  });

  test(
    'pagination follows metadata even for a short or full final page',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await http.runWithClient(
        () async {
          await vm.search('query');
          expect(vm.hasMoreResults, isTrue);
          await vm.loadMore();
          expect(vm.hasMoreResults, isFalse);
        },
        () => MockClient(
          (request) async => request.url.queryParameters['page'] == '1'
              ? page('first', count: 1, hasNext: true)
              : page('last', count: 30),
        ),
      );
    },
  );

  test(
    'disabling saved filters survives restart and clears previously saved filters',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      vm.setSearchGrade(SearchGrade.daif);
      vm.setExcludedWords('old exclusion');
      await vm.saveAdvancedPrefs();
      await vm.setSaveAdvancedSettings(false);
      final restored = SearchViewModel();
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.saveAdvancedSettings, isFalse);
      expect(restored.searchGrade, SearchGrade.all);
      expect(restored.excludedWords, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('searchGrade'), isFalse);
    },
  );
}
