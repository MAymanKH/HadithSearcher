import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/viewmodels/search_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'live catalogs expose additional options and narrator filters reach Dorar',
    () => HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({});
      final vm = SearchViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.preloadCatalogs();
      expect(vm.searchWays.length, greaterThan(1));
      expect(vm.searchRanges.length, greaterThan(1));
      for (final filter in SearchFilter.values) {
        final result = await vm.loadFilterOptions(filter);
        expect(
          result.isSuccess,
          isTrue,
          reason: '${filter.endpoint}: ${result.error}',
        );
        final options = result.data!;
        expect(options.length, greaterThan(1));
        expect(options.first.apiCode, filter.all.apiCode);
        if (filter == SearchFilter.narrator) {
          vm.setSelectedOptions(SearchFilter.narrator, [
            options.firstWhere((option) => option.apiCode == '8918'),
          ]);
        }
      }
      await vm.search('الأعمال');
      expect(vm.errorMessage, isNull);
      expect(vm.results, isNotEmpty);
      expect(
        vm.results.every((hadith) => hadith.rawi.contains('عمر بن الخطاب')),
        isTrue,
      );
    }, _LiveHttpOverrides()),
    skip: !const bool.fromEnvironment('VERIFY_LIVE_FILTERS'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _LiveHttpOverrides extends HttpOverrides {}
