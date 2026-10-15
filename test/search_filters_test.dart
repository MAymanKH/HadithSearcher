import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const books = [
    SearchOption('6216', 'صحيح البخاري'),
    SearchOption('3088', 'صحيح مسلم'),
  ];

  test(
    'multiple selections and specialist survive restart and pagination',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      vm.toggleAdvancedSearch();
      expect(vm.hasSettingsChanged(), isFalse);
      vm.setSelectedOptions(SearchFilter.book, books);
      vm.setSelectedOptions(SearchFilter.grade, [
        SearchOption.grades[1],
        SearchOption.grades[2],
      ]);
      vm.setSpecialist(true);
      expect(vm.hasSettingsChanged(), isTrue);
      await vm.saveAdvancedPrefs();
      final restored = SearchViewModel();
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.specialist, isTrue);
      expect(
        restored.selectedOptions(SearchFilter.book).map((o) => o.apiCode),
        ['3088', '6216'],
      );
      var requests = 0;
      await http.runWithClient(
        () async {
          await restored.search('حديث & نية');
          // Editing controls while results load must not change the pagination snapshot.
          restored.resetFilters();
          await restored.loadMore();
        },
        () => MockClient((request) async {
          requests++;
          final query = request.url.queryParametersAll;
          expect(query['specialist'], ['true']);
          expect(query['s[]'], ['3088', '6216']);
          expect(query['d[]'], ['1', '2']);
          expect(query['value'], ['حديث & نية']);
          return http.Response(
            jsonEncode({
              'metadata': {'hasNextPage': requests == 1},
              'data': [
                {'hadithId': '$requests', 'hadith': 'حديث'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(requests, 2);
      expect(restored.activeFilters, isEmpty);
    },
  );

  test(
    'saved single filters migrate and disabling save removes new selections',
    () async {
      SharedPreferences.setMockInitialValues({
        'searchGrade': 'أحاديث صحيحة',
        'searchBook': '6216',
        'searchBook.label': 'صحيح البخاري',
      });
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.selectedOptions(SearchFilter.grade).single.apiCode, '1');
      expect(vm.selectedOptions(SearchFilter.book).single.apiCode, '6216');
      vm.setSpecialist(true);
      vm.setSelectedOptions(SearchFilter.book, books);
      await vm.saveAdvancedPrefs();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('searchBook'), isFalse);
      expect(prefs.containsKey('searchFilters'), isTrue);
      await vm.setSaveAdvancedSettings(false);
      expect(prefs.containsKey('searchFilters'), isFalse);
      expect(prefs.containsKey('searchSpecialist'), isFalse);
      final restored = SearchViewModel();
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.specialist, isFalse);
      expect(restored.activeFilters, isEmpty);
    },
  );

  test(
    'request filters are immutable snapshots and all uses the zero sentinel',
    () {
      final selected = books.toList();
      final filters = {SearchFilter.book: selected};
      final params = SearchParams(keyword: 'نية', filters: filters);
      selected.clear();
      filters.clear();
      expect(params.toQueryParams()['s[]'], ['6216', '3088']);
      expect(params.toQueryParams()['d[]'], ['0']);
      expect(params.nextPage().toQueryParams()['s[]'], ['6216', '3088']);
    },
  );
  test(
    'filter row visibility persists independently of saving search filters',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.setShowActiveFilters(false);
      await vm.setSaveAdvancedSettings(false);
      final restarted = SearchViewModel();
      addTearDown(restarted.dispose);
      await restarted.init();
      expect(restarted.showActiveFilters, isFalse);
      expect(restarted.saveAdvancedSettings, isFalse);
      await restarted.setShowActiveFilters(true);
      final restored = SearchViewModel();
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.showActiveFilters, isTrue);
    },
  );

  test(
    'bulk selection is saved as all without sending every catalog ID',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      vm.setSelectedOptions(SearchFilter.narrator, [SearchOption.allNarrators]);
      await vm.saveAdvancedPrefs();
      final restored = SearchViewModel();
      addTearDown(restored.dispose);
      await restored.init();
      expect(
        restored.selectedOptions(SearchFilter.narrator).single.apiCode,
        '0',
      );
      expect(restored.activeFilters, isEmpty);
      final params = SearchParams(
        keyword: 'نية',
        filters: {
          SearchFilter.narrator: restored.selectedOptions(
            SearchFilter.narrator,
          ),
        },
      );
      expect(params.toQueryParams()['rawi[]'], ['0']);
    },
  );
}
