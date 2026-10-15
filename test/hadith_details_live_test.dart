import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/models/search_option.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deployed API supports specialist multi-filter search and source details',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final api = ApiService();
      final search = await api.searchHadith(
        SearchParams(
          keyword: 'الأعمال',
          specialist: true,
          filters: {
            SearchFilter.book: [SearchOption.books[2], SearchOption.books[3]],
          },
        ),
      );
      expect(search.isSuccess, isTrue, reason: search.error?.name);
      expect(search.data, isNotEmpty);
      expect(
        search.data!.every(
          (hadith) => ['6216', '3088'].contains(hadith.bookId),
        ),
        isTrue,
      );
      final hadith = search.data!.firstWhere((hadith) => hadith.hasUsulHadith);
      expect(hadith.categories, isNotEmpty);
      final book = await api.getBookDetails(hadith.bookId!);
      expect(book.isSuccess, isTrue, reason: book.error?.name);
      expect(book.data!.name, isNotEmpty);
      final scholar = await api.getScholarDetails(hadith.mohdithId!);
      expect(scholar.isSuccess, isTrue, reason: scholar.error?.name);
      expect(scholar.data!.info, isNotEmpty);
      final origins = await api.getHadithOrigins(hadith.id);
      expect(origins.isSuccess, isTrue, reason: origins.error?.name);
      expect(origins.data!.sources, isNotEmpty);
    }, _LiveHttpOverrides()),
    skip: !const bool.fromEnvironment('VERIFY_LIVE_DETAILS'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _LiveHttpOverrides extends HttpOverrides {}
