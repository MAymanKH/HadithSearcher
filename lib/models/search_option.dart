import 'dart:convert';

class SearchOption {
  final String apiCode;
  final String arabicName;

  const SearchOption(this.apiCode, this.arabicName);

  factory SearchOption.fromJson(Map<String, dynamic> json) =>
      SearchOption(json['key'].toString(), json['value'] as String);

  Map<String, String> toJson() => {'key': apiCode, 'value': arabicName};

  static List<SearchOption> decodeCatalog(String body) {
    final json = jsonDecode(body);
    final data = json is List ? json : json['data'] as List;
    return data
        .map<SearchOption>(
          (item) => SearchOption.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static String encodeCatalog(List<SearchOption> options) =>
      jsonEncode(options.map((option) => option.toJson()).toList());

  static const allGrades = SearchOption('0', 'جميع الدرجات');
  static const allScholars = SearchOption('0', 'جميع المحدثين');
  static const allBooks = SearchOption('0', 'جميع الكتب');
  static const allNarrators = SearchOption('0', 'جميع الرواة');
}

enum SearchFilter {
  grade('degree', 'درجة الحديث', SearchOption.allGrades, 'd[]'),
  scholar('mohdith', 'المحدث', SearchOption.allScholars, 'm[]'),
  book('book', 'الكتاب', SearchOption.allBooks, 's[]'),
  narrator('rawi', 'الراوي', SearchOption.allNarrators, 'rawi[]');

  final String endpoint;
  final String queryKey;
  final String arabicName;
  final SearchOption all;

  const SearchFilter(this.endpoint, this.arabicName, this.all, this.queryKey);

  String? get exclusionQueryKey => switch (this) {
    SearchFilter.grade => null,
    SearchFilter.scholar => 'xm[]',
    SearchFilter.book => 'xs[]',
    SearchFilter.narrator => 'xrawi[]',
  };
}
