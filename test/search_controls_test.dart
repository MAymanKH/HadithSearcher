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

  test(
    'catalog options persist and an arbitrary selection survives restart',
    () async {
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await http.runWithClient(
        vm.refreshFilterCatalogs,
        () => MockClient(
          (request) async => http.Response(
            jsonEncode([
              {'key': '0', 'value': 'الجميع'},
              {
                'key': '999',
                'value': request.url.path.endsWith('book')
                    ? 'كتاب آخر'
                    : 'محدث آخر',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      vm.setSearchBook(vm.books.last);
      vm.setSearchMohdith(vm.scholars.last);
      await vm.saveAdvancedPrefs();
      final restored = SearchViewModel();
      addTearDown(restored.dispose);
      await restored.init();
      expect(restored.books.last.apiCode, '999');
      expect(restored.searchBook.apiCode, '999');
      expect(restored.searchMohdith.apiCode, '999');
      expect(
        SearchParams(
          keyword: 'text',
          searchBook: restored.searchBook,
        ).toQueryParams()['s[]'],
        '999',
      );
    },
  );

  test(
    'legacy labels migrate even when the live catalog uses a different label',
    () async {
      SharedPreferences.setMockInitialValues({
        'searchBook': 'صحيح البخاري',
        'filterCatalog.book': jsonEncode([
          {'key': '0', 'value': 'الجميع'},
          {'key': '6216', 'value': 'الجامع الصحيح'},
        ]),
      });
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.searchBook.apiCode, '6216');
      expect(vm.searchBook.arabicName, 'الجامع الصحيح');
      vm.resetFilters();
      expect(vm.activeFilters, isEmpty);
      expect(vm.searchBook, SearchOption.allBooks);
    },
  );
}
