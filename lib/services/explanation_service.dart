import 'api_service.dart';
import 'database_service.dart';

class ExplanationService {
  static final _instance = ExplanationService._();
  factory ExplanationService() => _instance;
  ExplanationService._();

  final _pending = <String, Future<ApiResult<String>>>{};

  Future<ApiResult<String>> getExplanation(
    String hadithId, {
    String? sharhId,
    String? explanation,
  }) => _pending.putIfAbsent(
    hadithId,
    () => _load(hadithId, sharhId, explanation).whenComplete(() {
      _pending.remove(hadithId);
    }),
  );

  Future<ApiResult<String>> _load(
    String hadithId,
    String? sharhId,
    String? explanation,
  ) async {
    FavouriteHadith? favourite;
    try {
      favourite = await DatabaseService().getFavourite(hadithId);
    } catch (_) {
      // Online explanations remain available if local storage is unavailable.
    }
    explanation = [
      explanation,
      favourite?.explanation,
      favourite?.details?.explanation,
    ].whereType<String>().where((text) => text.trim().isNotEmpty).firstOrNull;
    sharhId ??= favourite?.sharhId ?? favourite?.details?.sharhId;
    if (explanation == null && sharhId == null) {
      final metadata = await ApiService().getHadithById(hadithId);
      if (metadata.isError) return ApiResult.error(metadata.error!);
      sharhId = metadata.data!.sharhId;
      explanation = metadata.data!.explanation;
    }
    if (explanation == null && sharhId == null) {
      return ApiResult.error(ApiError.notFound);
    }
    final result = explanation != null
        ? ApiResult.success(explanation)
        : await ApiService().getSharh(sharhId!);
    if (result.isSuccess && result.data != favourite?.explanation) {
      await DatabaseService().saveExplanation(hadithId, sharhId, result.data!);
    }
    return result;
  }
}
