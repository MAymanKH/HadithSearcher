import 'search_option.dart';

class SearchParams {
  final String keyword;
  final int page;
  final SearchWay searchWay;
  final SearchRange searchRange;
  final Map<SearchFilter, List<SearchOption>> filters;
  final Map<SearchFilter, List<SearchOption>> exclusions;
  final bool specialist;
  final String excludedWords;

  SearchParams({
    required this.keyword,
    this.page = 1,
    this.searchWay = SearchWay.anyWord,
    this.searchRange = SearchRange.all,
    Map<SearchFilter, List<SearchOption>> filters = const {},
    Map<SearchFilter, List<SearchOption>> exclusions = const {},
    this.specialist = false,
    this.excludedWords = '',
  }) : filters = Map.unmodifiable(
         filters.map(
           (filter, options) =>
               MapEntry(filter, List<SearchOption>.unmodifiable(options)),
         ),
       ),
       exclusions = Map.unmodifiable(
         exclusions.map(
           (filter, options) =>
               MapEntry(filter, List<SearchOption>.unmodifiable(options)),
         ),
       );

  SearchParams _withPage(int page) => SearchParams(
    keyword: keyword,
    page: page,
    searchWay: searchWay,
    searchRange: searchRange,
    filters: filters,
    exclusions: exclusions,
    specialist: specialist,
    excludedWords: excludedWords,
  );

  SearchParams nextPage() => _withPage(page + 1);
  SearchParams resetPage() => _withPage(1);

  Map<String, Object> toQueryParams() => {
    'value': keyword,
    'page': page.toString(),
    'st': searchWay.apiCode,
    't': searchRange.apiCode,
    'specialist': specialist.toString(),
    for (final filter in SearchFilter.values)
      filter.queryKey: filters[filter]?.isNotEmpty == true
          ? filters[filter]!.map((option) => option.apiCode).toList()
          : ['0'],
    for (final entry in exclusions.entries)
      if (entry.value.isNotEmpty && entry.key.exclusionQueryKey != null)
        entry.key.exclusionQueryKey!: entry.value
            .map((option) => option.apiCode)
            .toList(),
    if (excludedWords.isNotEmpty) 'xclude': excludedWords,
  };

  String toQueryString() => Uri(queryParameters: toQueryParams()).query;
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
