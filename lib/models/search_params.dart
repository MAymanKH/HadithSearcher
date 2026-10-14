import 'search_option.dart';

/// Search parameters for the Hadith API.
class SearchParams {
  final String keyword;
  final int page;
  final SearchWay searchWay;
  final SearchRange searchRange;
  final SearchGrade searchGrade;
  final SearchOption searchMohdith;
  final SearchOption searchBook;
  final String excludedWords;

  const SearchParams({
    required this.keyword,
    this.page = 1,
    this.searchWay = SearchWay.anyWord,
    this.searchRange = SearchRange.all,
    this.searchGrade = SearchGrade.all,
    this.searchMohdith = SearchOption.allScholars,
    this.searchBook = SearchOption.allBooks,
    this.excludedWords = '',
  });

  /// Creates a copy with updated page number.
  SearchParams nextPage() {
    return SearchParams(
      keyword: keyword,
      page: page + 1,
      searchWay: searchWay,
      searchRange: searchRange,
      searchGrade: searchGrade,
      searchMohdith: searchMohdith,
      searchBook: searchBook,
      excludedWords: excludedWords,
    );
  }

  /// Creates a copy with reset page.
  SearchParams resetPage() {
    return SearchParams(
      keyword: keyword,
      page: 1,
      searchWay: searchWay,
      searchRange: searchRange,
      searchGrade: searchGrade,
      searchMohdith: searchMohdith,
      searchBook: searchBook,
      excludedWords: excludedWords,
    );
  }

  /// Builds query parameters for API URL.
  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'value': keyword,
      'page': page.toString(),
      'st': searchWay.apiCode,
      't': searchRange.apiCode,
      'd[]': searchGrade.apiCode,
      'm[]': searchMohdith.apiCode,
      's[]': searchBook.apiCode,
    };

    // Add excluded words if present
    if (excludedWords.isNotEmpty) {
      params['xclude'] = excludedWords;
    }

    return params;
  }

  /// Builds full query string.
  String toQueryString() {
    final buffer = StringBuffer();
    buffer.write('value=$keyword');
    buffer.write('&page=$page');
    buffer.write('&st=${searchWay.apiCode}');
    buffer.write('&t=${searchRange.apiCode}');
    buffer.write('&d[]=${searchGrade.apiCode}');
    buffer.write('&m[]=${searchMohdith.apiCode}');
    buffer.write('&s[]=${searchBook.apiCode}');
    if (excludedWords.isNotEmpty) {
      buffer.write(excludedWords);
    }
    return buffer.toString();
  }
}

/// Search method (any word, all words, exact match).
enum SearchWay {
  anyWord('a', 'أي كلمة'),
  allWords('w', 'جميع الكلمات'),
  exactMatch('p', 'بحث مطابق');

  final String apiCode;
  final String arabicName;

  const SearchWay(this.apiCode, this.arabicName);

  static SearchWay fromArabic(String name) {
    return SearchWay.values.firstWhere(
      (e) => e.arabicName == name,
      orElse: () => SearchWay.anyWord,
    );
  }
}

/// Hadith range/type filter.
enum SearchRange {
  all('*', 'جميع الأحاديث'),
  marfoo('0', 'الأحاديث المرفوعة'),
  qudsi('1', 'الأحاديث القدسية'),
  athar('2', 'آثار الصحابة'),
  sharh('3', 'شروح الأحاديث');

  final String apiCode;
  final String arabicName;

  const SearchRange(this.apiCode, this.arabicName);

  static SearchRange fromArabic(String name) {
    return SearchRange.values.firstWhere(
      (e) => e.arabicName == name,
      orElse: () => SearchRange.all,
    );
  }
}

/// Hadith authenticity grade filter.
enum SearchGrade {
  all('0', 'جميع الدرجات'),
  sahih('1', 'أحاديث صحيحة'),
  sahihIsnad('2', 'أحاديث أسانيدها صحيحة'),
  daif('3', 'أحاديث ضعيفة'),
  daifIsnad('4', 'أحاديث أسانيدها ضعيفة');

  final String apiCode;
  final String arabicName;

  const SearchGrade(this.apiCode, this.arabicName);

  static SearchGrade fromArabic(String name) {
    return SearchGrade.values.firstWhere(
      (e) => e.arabicName == name,
      orElse: () => SearchGrade.all,
    );
  }
}
