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
  }) => _pending.putIfAbsent(
    hadithId,
    () => _load(hadithId, sharhId).whenComplete(() {
      _pending.remove(hadithId);
    }),
  );

  Future<ApiResult<String>> _load(String hadithId, String? sharhId) async {
    FavouriteHadith? favourite;
    try {
      favourite = await DatabaseService().getFavourite(hadithId);
    } catch (_) {
      // Online explanations remain available if local storage is unavailable.
    }
    if (favourite?.explanation != null) {
      return ApiResult.success(favourite!.explanation!);
    }
    sharhId ??= favourite?.sharhId;
    if (sharhId == null) {
      final metadata = await ApiService().getHadithById(hadithId);
      if (metadata.isError) return ApiResult.error(metadata.error!);
      sharhId = metadata.data!.sharhId;
      if (sharhId == null) return ApiResult.error(ApiError.notFound);
    }
    final result = await ApiService().getSharh(sharhId);
    if (result.isSuccess) {
      await DatabaseService().saveExplanation(hadithId, sharhId, result.data!);
    }
    return result;
  }
}
