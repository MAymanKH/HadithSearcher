import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/search_option.dart';

const grades = [
  SearchOption.allGrades,
  SearchOption('1', 'أحاديث صحيحة'),
  SearchOption('2', 'أحاديث أسانيدها صحيحة'),
  SearchOption('3', 'أحاديث ضعيفة'),
  SearchOption('4', 'أحاديث أسانيدها ضعيفة'),
];

Future<void> seedCatalogCache({bool includeNarrators = true}) async {
  final prefs = await SharedPreferences.getInstance();
  final catalogs = {
    'degree': grades,
    'methodSearch': const [
      SearchOption('a', 'أي كلمة'),
      SearchOption('w', 'جميع الكلمات'),
      SearchOption('p', 'بحث مطابق'),
    ],
    'zoneSearch': const [
      SearchOption('*', 'جميع الأحاديث'),
      SearchOption('0', 'الأحاديث المرفوعة'),
      SearchOption('1', 'الأحاديث القدسية'),
      SearchOption('2', 'آثار الصحابة'),
      SearchOption('3', 'شروح الأحاديث'),
    ],
    'book': const [SearchOption('6216', 'صحيح البخاري')],
    'mohdith': const [SearchOption('256', 'البخاري')],
    if (includeNarrators) 'rawi': const [SearchOption('8918', 'عمر بن الخطاب')],
  };
  for (final entry in catalogs.entries) {
    await prefs.setString(
      'filterCatalog.${entry.key}',
      SearchOption.encodeCatalog(entry.value),
    );
    await prefs.setInt(
      'filterCatalog.${entry.key}.savedAt',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

Future<void> finishCatalogPreload(
  WidgetTester tester,
  Future<void> preload,
) async {
  var complete = false;
  preload.then((_) => complete = true);
  await tester.runAsync(() async {
    for (var i = 0; i < 200 && !complete; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  expect(complete, isTrue, reason: 'Catalog preload should finish');
}
