class HadithCategory {
  final String id;
  final String name;

  const HadithCategory({required this.id, required this.name});

  factory HadithCategory.fromJson(Map<String, dynamic> json) => HadithCategory(
    id: json['id']?.toString() ?? '',
    name: json['name'] ?? '',
  );
}

class HadithSource {
  final String source;
  final String chain;
  final String text;

  const HadithSource({
    required this.source,
    required this.chain,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
    'source': source,
    'chain': chain,
    'hadithText': text,
  };

  factory HadithSource.fromJson(Map<String, dynamic> json) => HadithSource(
    source: json['source'] ?? '',
    chain: json['chain'] ?? '',
    text: json['hadithText'] ?? '',
  );
}

class HadithOrigins {
  final List<HadithSource> sources;

  const HadithOrigins(this.sources);

  Map<String, dynamic> toJson() => {
    'sources': sources.map((source) => source.toJson()).toList(),
  };

  factory HadithOrigins.fromJson(Map<String, dynamic> json) => HadithOrigins(
    (json['sources'] as List? ?? const [])
        .map((source) => HadithSource.fromJson(source as Map<String, dynamic>))
        .where(
          (source) =>
              source.source.isNotEmpty ||
              source.chain.isNotEmpty ||
              source.text.isNotEmpty,
        )
        .toList(),
  );
}

class BookDetails {
  final String name;
  final String author;
  final String reviewer;
  final String publisher;
  final String edition;
  final String editionYear;

  const BookDetails({
    required this.name,
    required this.author,
    required this.reviewer,
    required this.publisher,
    required this.edition,
    required this.editionYear,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'author': author,
    'reviewer': reviewer,
    'publisher': publisher,
    'edition': edition,
    'editionYear': editionYear,
  };

  factory BookDetails.fromJson(Map<String, dynamic> json) => BookDetails(
    name: json['name'] ?? '',
    author: json['author'] ?? '',
    reviewer: json['reviewer'] ?? '',
    publisher: json['publisher'] ?? '',
    edition: json['edition']?.toString() ?? '',
    editionYear: json['editionYear']?.toString() ?? '',
  );
}

class ScholarDetails {
  final String name;
  final String info;

  const ScholarDetails({required this.name, required this.info});

  Map<String, dynamic> toJson() => {'name': name, 'info': info};

  factory ScholarDetails.fromJson(Map<String, dynamic> json) =>
      ScholarDetails(name: json['name'] ?? '', info: json['info'] ?? '');
}
