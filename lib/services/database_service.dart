import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/hadith_citation.dart';
import '../models/hadith.dart';
import '../models/hadith_details.dart';
import 'telemetry/telemetry_service.dart';

/// Service for local SQLite database operations (favourites only).
class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;
  static Future<Database>? _opening;

  /// Get database instance, initializing if needed.
  Future<Database> get database async {
    try {
      _db ??= await (_opening ??= _initDb());
      return _db!;
    } finally {
      _opening = null;
    }
  }

  /// Initialize the database.
  Future<Database> _initDb() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'hadithsearcher.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favourites (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        hadithtext TEXT NOT NULL,
        hadithinfo TEXT NOT NULL,
        hadithid TEXT NOT NULL UNIQUE,
        sharhid TEXT,
        explanation TEXT,
        details TEXT,
        origins TEXT,
        hasalternate INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Drop settings table if upgrading from version 1
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS settings');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE favourites ADD COLUMN details TEXT');
      await db.execute('ALTER TABLE favourites ADD COLUMN origins TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE favourites ADD COLUMN sharhid TEXT');
      await db.execute('ALTER TABLE favourites ADD COLUMN explanation TEXT');
      await db.execute(
        'ALTER TABLE favourites ADD COLUMN hasalternate INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // ==================== FAVOURITES ====================

  /// Get all favourite hadiths.
  Future<List<FavouriteHadith>> getFavourites() async {
    try {
      final db = await database;
      final results = await db.query('favourites', orderBy: 'id DESC');

      return results.map((row) => FavouriteHadith.fromDatabase(row)).toList();
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'database.getFavourites');
      return [];
    }
  }

  /// Check if a hadith is in favourites.
  Future<bool> isFavourite(String hadithId) async {
    try {
      final db = await database;
      final results = await db.query(
        'favourites',
        where: 'hadithid = ?',
        whereArgs: [hadithId],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'database.isFavourite');
      return false;
    }
  }

  /// Add a hadith to favourites.
  Future<bool> addFavourite({
    required String hadithId,
    required String hadithText,
    required String hadithInfo,
    String? sharhId,
    bool hasAlternate = false,
    Hadith? hadith,
  }) async {
    try {
      final db = await database;
      final inserted = await TelemetryService.trace(
        'database.addFavourite',
        () => db.insert('favourites', {
          'details': hadith == null ? null : jsonEncode(hadith.toJson()),
          'hadithid': hadithId,
          'hadithtext': hadithText,
          'hadithinfo': hadithInfo,
          'sharhid': sharhId ?? hadith?.sharhId,
          'explanation': hadith?.explanation,
          'hasalternate': hasAlternate ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore),
      );
      if (inserted != 0) {
        TelemetryService.event('favourite_added', {'hadith_id': hadithId});
        notifyListeners();
      }
      return true;
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'database.addFavourite');
      return false;
    }
  }

  /// Remove a hadith from favourites.
  Future<bool> removeFavourite(String hadithId) async {
    try {
      final db = await database;
      final removed = await TelemetryService.trace(
        'database.removeFavourite',
        () => db.delete(
          'favourites',
          where: 'hadithid = ?',
          whereArgs: [hadithId],
        ),
      );
      if (removed > 0) {
        TelemetryService.event('favourite_removed', {'hadith_id': hadithId});
        notifyListeners();
      }
      return true;
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'database.removeFavourite');
      return false;
    }
  }

  Future<FavouriteHadith?> getFavourite(String hadithId) async {
    final db = await database;
    final rows = await db.query(
      'favourites',
      where: 'hadithid = ?',
      whereArgs: [hadithId],
      limit: 1,
    );
    return rows.isEmpty ? null : FavouriteHadith.fromDatabase(rows.first);
  }

  Future<bool> restoreFavourite(FavouriteHadith favourite) async {
    try {
      final db = await database;
      await db.insert(
        'favourites',
        favourite.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      notifyListeners();
      return true;
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'database.restoreFavourite');
      return false;
    }
  }

  Future<void> saveExplanation(
    String hadithId,
    String? sharhId,
    String explanation,
  ) async {
    try {
      final db = await database;
      final changed = await db.update(
        'favourites',
        {'sharhid': sharhId, 'explanation': explanation},
        where: 'hadithid = ?',
        whereArgs: [hadithId],
      );
      if (changed > 0) notifyListeners();
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'database.saveExplanation');
    }
  }

  Future<void> saveDetails(Hadith hadith) async {
    final db = await database;
    final changed = await db.update(
      'favourites',
      {'details': jsonEncode(hadith.toJson())},
      where: 'hadithid = ?',
      whereArgs: [hadith.id],
    );
    if (changed > 0) notifyListeners();
  }

  Future<void> saveOrigins(String hadithId, HadithOrigins origins) async {
    final db = await database;
    final changed = await db.update(
      'favourites',
      {'origins': jsonEncode(origins.toJson())},
      where: 'hadithid = ?',
      whereArgs: [hadithId],
    );
    if (changed > 0) notifyListeners();
  }

  /// Get all favourite hadith IDs (for bulk checking).
  Future<Set<String>> getFavouriteIds() async {
    try {
      final db = await database;
      final results = await db.query('favourites', columns: ['hadithid']);
      return results.map((row) => row['hadithid'] as String).toSet();
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'database.getFavouriteIds');
      return {};
    }
  }
}

/// Favourite hadith with stored text and info.
class FavouriteHadith {
  final int id;
  final String hadithId;
  final String hadithText;
  final String hadithInfo;
  final String? sharhId;
  final String? explanation;
  final bool hasAlternate;
  final Hadith? details;
  final HadithOrigins? origins;

  const FavouriteHadith({
    required this.id,
    required this.hadithId,
    required this.hadithText,
    required this.hadithInfo,
    this.sharhId,
    this.explanation,
    this.hasAlternate = false,
    this.details,
    this.origins,
  });

  bool get hasSimilarHadith => details?.hasSimilarHadith ?? false;

  bool get hasExplanation =>
      details?.hasExplanation == true ||
      (sharhId != null && sharhId!.isNotEmpty && sharhId != '0') ||
      explanation?.trim().isNotEmpty == true;

  factory FavouriteHadith.fromDatabase(Map<String, dynamic> row) {
    return FavouriteHadith(
      id: row['id'] as int,
      hadithId: row['hadithid'] as String,
      hadithText: row['hadithtext'] as String,
      hadithInfo: row['hadithinfo'] as String,
      sharhId: row['sharhid'] as String?,
      explanation: row['explanation'] as String?,
      hasAlternate: row['hasalternate'] == 1,
      details: row['details'] == null
          ? null
          : Hadith.fromJson(jsonDecode(row['details'] as String)),
      origins: row['origins'] == null
          ? null
          : HadithOrigins.fromJson(jsonDecode(row['origins'] as String)),
    );
  }

  Map<String, Object?> toDatabase() => {
    'details': details == null ? null : jsonEncode(details!.toJson()),
    'origins': origins == null ? null : jsonEncode(origins!.toJson()),
    'id': id,
    'hadithid': hadithId,
    'hadithtext': hadithText,
    'hadithinfo': hadithInfo,
    'sharhid': sharhId,
    'explanation': explanation,
    'hasalternate': hasAlternate ? 1 : 0,
  };

  /// Full text for display.
  String get displayText => '$hadithText\n\n$hadithInfo';

  /// Full text for sharing.
  String get shareText {
    final citation = HadithCitation.tryParse(hadithInfo);
    return '$hadithText\n\n${citation?.combinedInfo ?? hadithInfo}';
  }
}
