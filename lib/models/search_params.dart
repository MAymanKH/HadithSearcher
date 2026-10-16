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
class SearchWay extends SearchOption {
  const SearchWay(super.apiCode, super.arabicName);

  // Known codes support defaults, localization, and old saved preferences.
  // Picker choices come from the API, including any new codes.
  static const anyWord = SearchWay('a', 'أي كلمة');
  static const allWords = SearchWay('w', 'جميع الكلمات');
  static const exactMatch = SearchWay('p', 'بحث مطابق');
  static const _legacyValues = [anyWord, allWords, exactMatch];

  @override
  bool operator ==(Object other) =>
      other is SearchWay && other.apiCode == apiCode;

  @override
  int get hashCode => Object.hash(SearchWay, apiCode);

  static SearchWay fromArabic(String name) {
    return _legacyValues.firstWhere(
      (e) => e.arabicName == name,
      orElse: () => SearchWay.anyWord,
    );
  }
}

/// Hadith range/type filter.
class SearchRange extends SearchOption {
  const SearchRange(super.apiCode, super.arabicName);

  static const all = SearchRange('*', 'جميع الأحاديث');
  static const marfoo = SearchRange('0', 'الأحاديث المرفوعة');
  static const qudsi = SearchRange('1', 'الأحاديث القدسية');
  static const athar = SearchRange('2', 'آثار الصحابة');
  static const sharh = SearchRange('3', 'شروح الأحاديث');
  static const _legacyValues = [all, marfoo, qudsi, athar, sharh];

  @override
  bool operator ==(Object other) =>
      other is SearchRange && other.apiCode == apiCode;

  @override
  int get hashCode => Object.hash(SearchRange, apiCode);

  static SearchRange fromArabic(String name) {
    return _legacyValues.firstWhere(
      (e) => e.arabicName == name,
      orElse: () => SearchRange.all,
    );
  }
}
