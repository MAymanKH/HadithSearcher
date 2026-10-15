import 'hadith_citation.dart';
import 'hadith_details.dart';

/// Represents a Hadith with all its metadata from the API.
class Hadith {
  final String id;
  final String text;
  final String rawi;
  final String mohdith;
  final String book;
  final String numberOrPage;
  final String grade;
  final String explainGrade;
  final String takhrij;
  final String? bookId;
  final String? mohdithId;
  final List<HadithCategory> categories;
  final bool hasUsulHadith;
  final bool hasSharhMetadata;
  final String? sharhId;
  final bool hasAlternateHadithSahih;

  const Hadith({
    required this.id,
    required this.text,
    required this.rawi,
    required this.mohdith,
    required this.book,
    required this.numberOrPage,
    required this.grade,
    this.explainGrade = '',
    this.takhrij = '',
    this.bookId,
    this.mohdithId,
    this.categories = const [],
    this.hasUsulHadith = false,
    this.hasSharhMetadata = false,
    this.sharhId,
    this.hasAlternateHadithSahih = false,
  });

  /// Creates a Hadith from API JSON response.
  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      id: json['hadithId']?.toString() ?? '',
      text: json['hadith'] ?? '',
      rawi: json['rawi'] ?? '',
      mohdith: json['mohdith'] ?? '',
      book: json['book'] ?? '',
      numberOrPage: json['numberOrPage'] ?? '',
      grade: json['grade'] ?? '',
      explainGrade: json['explainGrade'] ?? '',
      takhrij: json['takhrij'] ?? '',
      bookId: json['bookId']?.toString(),
      mohdithId: json['mohdithId']?.toString(),
      categories: (json['categories'] as List? ?? const [])
          .map(
            (category) =>
                HadithCategory.fromJson(category as Map<String, dynamic>),
          )
          .where((category) => category.name.trim().isNotEmpty)
          .toList(),
      hasUsulHadith: json['hasUsulHadith'] == true,
      hasSharhMetadata: json['hasSharhMetadata'] ?? false,
      sharhId: json['sharhMetadata']?['id']?.toString(),
      hasAlternateHadithSahih: json['hasAlternateHadithSahih'] == true,
    );
  }

  /// Creates a Hadith from local database row.
  factory Hadith.fromDatabase(Map<String, dynamic> row) {
    final citation = HadithCitation.tryParse(row['hadithinfo'] ?? '');
    return Hadith(
      id: row['hadithid'] ?? '',
      text: row['hadithtext'] ?? '',
      rawi: citation?.rawi ?? '',
      mohdith: citation?.mohdith ?? '',
      book: citation?.book ?? '',
      numberOrPage: citation?.numberOrPage ?? '',
      grade: citation?.grade ?? '',
      hasSharhMetadata: false,
      sharhId: null,
    );
  }

  /// Converts to map for database insertion.
  Map<String, dynamic> toDatabase() {
    return {'hadithid': id, 'hadithtext': text, 'hadithinfo': formattedInfo};
  }

  HadithCitation get citation => HadithCitation(
    rawi: rawi,
    mohdith: mohdith,
    book: book,
    numberOrPage: numberOrPage,
    grade: grade,
  );

  /// Formatted hadith info string for display.
  String get formattedInfo => citation.formattedInfo;

  /// Full text for sharing.
  String get shareText => '$text\n\n${citation.combinedInfo}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hadith && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
