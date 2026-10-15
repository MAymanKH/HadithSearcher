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

  static const grades = [
    SearchOption('0', 'جميع الدرجات'),
    SearchOption('1', 'أحاديث صحيحة'),
    SearchOption('2', 'أحاديث أسانيدها صحيحة'),
    SearchOption('3', 'أحاديث ضعيفة'),
    SearchOption('4', 'أحاديث أسانيدها ضعيفة'),
  ];

  static const allScholars = SearchOption('0', 'جميع المحدثين');
  static const allBooks = SearchOption('0', 'جميع الكتب');
  static const allNarrators = SearchOption('0', 'جميع الرواة');
  static const scholars = [
    allScholars,
    SearchOption('179', 'الإمام مالك'),
    SearchOption('204', 'الإمام الشافعي'),
    SearchOption('256', 'البخاري'),
    SearchOption('261', 'مسلم'),
    SearchOption('385', 'الدارقطني'),
    SearchOption('852', 'ابن حجر العسقلاني'),
    SearchOption('232', 'يحيى بن معين'),
  ];
  static const books = [
    allBooks,
    SearchOption('13457', 'الأربعون النووية'),
    SearchOption('6216', 'صحيح البخاري'),
    SearchOption('3088', 'صحيح مسلم'),
    SearchOption('96', 'الصحيح المسند'),
  ];
  static const narrators = [allNarrators];
}

enum SearchFilter {
  grade('degree', 'درجة الحديث', SearchOption.grades, 'd[]'),
  scholar('mohdith', 'المحدث', SearchOption.scholars, 'm[]'),
  book('book', 'الكتاب', SearchOption.books, 's[]'),
  narrator('rawi', 'الراوي', SearchOption.narrators, 'rawi[]');

  final String endpoint;
  final String queryKey;
  final String arabicName;
  final List<SearchOption> fallbackOptions;

  const SearchFilter(
    this.endpoint,
    this.arabicName,
    this.fallbackOptions,
    this.queryKey,
  );

  SearchOption get all => fallbackOptions.first;

  String? get exclusionQueryKey => switch (this) {
    SearchFilter.grade => null,
    SearchFilter.scholar => 'excludeMohdith[]',
    SearchFilter.book => 'excludeBook[]',
    SearchFilter.narrator => 'excludeRawi[]',
  };
}
