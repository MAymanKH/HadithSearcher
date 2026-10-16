class HadithCitation {
  final String rawi;
  final String mohdith;
  final String book;
  final String numberOrPage;
  final String grade;

  const HadithCitation({
    required this.rawi,
    required this.mohdith,
    required this.book,
    required this.numberOrPage,
    required this.grade,
  });

  static final _storedFormat = RegExp(
    r'^الراوي: (.*?)\nالمحدث: (.*?)\nالمصدر: (.*?)\nالصفحة أو الرقم: (.*?)\nخلاصة حكم المحدث: (.*)$',
    dotAll: true,
  );

  static HadithCitation? tryParse(String info) {
    final match = _storedFormat.firstMatch(info);
    if (match == null) return null;
    return HadithCitation(
      rawi: match[1]!,
      mohdith: match[2]!,
      book: match[3]!,
      numberOrPage: match[4]!,
      grade: match[5]!,
    );
  }

  String get grading => mohdith.trim().isEmpty
      ? 'خلاصة حكم المحدث: $grade'
      : 'حكم $mohdith: $grade';

  String get attribution =>
      'الراوي: $rawi\nالمصدر: $book\nالصفحة أو الرقم: $numberOrPage';

  String get compactSource {
    final reference = [
      book,
      if (numberOrPage.trim().isNotEmpty) '(${numberOrPage.trim()})',
    ].map((value) => value.trim()).where((value) => value.isNotEmpty).join(' ');
    return [
      mohdith.trim(),
      reference,
    ].where((value) => value.isNotEmpty).join('، ');
  }

  String get combinedInfo => '$grading\n$attribution';

  String get formattedInfo =>
      'الراوي: $rawi\n'
      'المحدث: $mohdith\n'
      'المصدر: $book\n'
      'الصفحة أو الرقم: $numberOrPage\n'
      'خلاصة حكم المحدث: $grade';
}
