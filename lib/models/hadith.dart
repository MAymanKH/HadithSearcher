import 'hadith_citation.dart';

/// Represents a Hadith with all its metadata from the API.
class Hadith {
  final String id;
  final String text;
  final String rawi;
  final String mohdith;
  final String book;
  final String numberOrPage;
  final String grade;
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
      hasSharhMetadata: json['hasSharhMetadata'] ?? false,
      sharhId: json['sharhMetadata']?['id']?.toString(),
      hasAlternateHadithSahih: json['hasAlternateHadithSahih'] == true,
    );
  }

  /// Creates a Hadith from local database row.
  factory Hadith.fromDatabase(Map<String, dynamic> row) {
    return Hadith(
      id: row['hadithid'] ?? '',
      text: row['hadithtext'] ?? '',
      rawi: '',
      mohdith: '',
      book: '',
      numberOrPage: '',
      grade: '',
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
  String get shareText {
    return '$text\n\n$formattedInfo';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hadith && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
