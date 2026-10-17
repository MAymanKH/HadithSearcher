import '../models/hadith.dart';
import '../models/hadith_details.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'explanation_service.dart';
import 'telemetry/telemetry_service.dart';

class FavouriteDetailsService {
  static final _instance = FavouriteDetailsService._();
  factory FavouriteDetailsService() => _instance;
  FavouriteDetailsService._();

  Future<void> _queue = Future.value();
  final _saving = <String, Future<void>>{};
  final _details = <String, Future<ApiResult<Hadith>>>{};
  final _origins = <String, Future<ApiResult<HadithOrigins>>>{};

  Future<void> saveOffline(Hadith hadith) => _saving.putIfAbsent(hadith.id, () {
    final work = _queue.then((_) async {
      try {
        if (!await DatabaseService().isFavourite(hadith.id)) return;
        final details = await getDetails(hadith.id);
        final full = details.data ?? hadith;
        if (!await DatabaseService().isFavourite(hadith.id)) return;
        await Future.wait([
          if (_hasSourceId(full.bookId ?? hadith.bookId))
            getBookDetails((full.bookId ?? hadith.bookId)!.trim()),
          if (_hasSourceId(full.mohdithId ?? hadith.mohdithId))
            getScholarDetails((full.mohdithId ?? hadith.mohdithId)!.trim()),
        ]);
        if (full.hasUsulHadith) await getOrigins(full.id);
        final sharhId = full.sharhId ?? hadith.sharhId;
        if (full.hasExplanation || hadith.hasExplanation) {
          await ExplanationService().getExplanation(
            full.id,
            sharhId: sharhId,
            explanation: full.explanation ?? hadith.explanation,
          );
        }
      } catch (error, stack) {
        TelemetryService.report(error, stack, 'favourites.saveOffline');
      }
    });
    _queue = work;
    return work.whenComplete(() {
      _saving.remove(hadith.id);
    });
  });

  bool _hasSourceId(String? id) =>
      id != null && id.trim().isNotEmpty && id.trim() != '0';

  Future<ApiResult<BookDetails>> getBookDetails(String id) => _sourceDetails(
    'book',
    id,
    BookDetails.fromJson,
    () => ApiService().getBookDetails(id),
    (book) => book.toJson(),
  );

  Future<ApiResult<ScholarDetails>> getScholarDetails(String id) =>
      _sourceDetails(
        'scholar',
        id,
        ScholarDetails.fromJson,
        () => ApiService().getScholarDetails(id),
        (scholar) => scholar.toJson(),
      );

  Future<ApiResult<T>> _sourceDetails<T extends Object>(
    String kind,
    String id,
    T Function(Map<String, dynamic>) parse,
    Future<ApiResult<T>> Function() load,
    Map<String, dynamic> Function(T) serialize,
  ) async {
    try {
      final saved = await DatabaseService().getSourceDetails(kind, id);
      if (saved != null) return ApiResult.success(parse(saved));
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'favourites.readSourceDetails');
      // Reading source information still works if local storage is unavailable.
    }
    final result = await load();
    if (result.isSuccess) {
      try {
        await DatabaseService().saveSourceDetails(
          kind,
          id,
          serialize(result.data!),
        );
      } catch (error, stack) {
        TelemetryService.report(error, stack, 'favourites.saveSourceDetails');
      }
    }
    return result;
  }

  Future<ApiResult<Hadith>> getDetails(String id) => _details.putIfAbsent(
    id,
    () => _loadDetails(id).whenComplete(() {
      _details.remove(id);
    }),
  );

  Future<ApiResult<Hadith>> _loadDetails(String id) async {
    // Fetch full metadata on save; the initial search snapshot can be partial.
    final result = await ApiService().getHadithById(id);
    if (result.isSuccess) {
      try {
        await DatabaseService().saveDetails(result.data!);
      } catch (error, stack) {
        TelemetryService.report(error, stack, 'favourites.saveDetails');
        // Details can still be read when local storage is unavailable.
      }
    }
    return result;
  }

  Future<ApiResult<Hadith>> getSavedDetails(String id) async {
    try {
      final saved = await DatabaseService().getFavourite(id);
      if (saved?.details != null) return ApiResult.success(saved!.details!);
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'favourites.readDetails');
      // Fall back to the source for unsaved hadiths.
    }
    return getDetails(id);
  }

  Future<ApiResult<HadithOrigins>> getOrigins(String id) =>
      _origins.putIfAbsent(
        id,
        () => _loadOrigins(id).whenComplete(() {
          _origins.remove(id);
        }),
      );

  Future<ApiResult<HadithOrigins>> _loadOrigins(String id) async {
    try {
      final saved = await DatabaseService().getFavourite(id);
      if (saved?.origins != null) return ApiResult.success(saved!.origins!);
    } catch (error, stack) {
      TelemetryService.report(error, stack, 'favourites.readOrigins');
      // Continue online when local storage is unavailable.
    }
    final result = await ApiService().getHadithOrigins(id);
    if (result.isSuccess) {
      try {
        await DatabaseService().saveOrigins(id, result.data!);
      } catch (error, stack) {
        TelemetryService.report(error, stack, 'favourites.saveOrigins');
        // Reading online does not depend on a successful local write.
      }
    }
    return result;
  }
}
