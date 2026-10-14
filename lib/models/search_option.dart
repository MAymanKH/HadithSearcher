class SearchOption {
  final String apiCode;
  final String arabicName;

  const SearchOption(this.apiCode, this.arabicName);

  factory SearchOption.fromJson(Map<String, dynamic> json) =>
      SearchOption(json['key'].toString(), json['value'] as String);

  Map<String, String> toJson() => {'key': apiCode, 'value': arabicName};

  static const allScholars = SearchOption('0', 'جميع المحدثين');
  static const allBooks = SearchOption('0', 'جميع الكتب');
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
}
