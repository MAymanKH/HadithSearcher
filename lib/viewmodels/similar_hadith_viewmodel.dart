import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hadith.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/explanation_service.dart';

/// ViewModel for similar hadith view.
class SimilarHadithViewModel extends ChangeNotifier {
  SimilarHadithViewModel() {
    _db.addListener(_refreshFavouriteIds);
  }

  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();

  List<Hadith> _results = [];
  Set<String> _favouriteIds = {};
  bool _isLoading = false;
  bool _disposed = false;
  int _requestGeneration = 0;
  String? _errorMessage;

  /// Similar hadiths results.
  List<Hadith> get results => _results;

  /// Whether data is loading.
  bool get isLoading => _isLoading;

  /// Error message if any.
  String? get errorMessage => _errorMessage;

  /// Whether results are empty.
  bool get isEmpty => _results.isEmpty && !_isLoading;

  /// Whether there are results.
  bool get hasResults => _results.isNotEmpty;

  Future<void> _refreshFavouriteIds() async {
    final ids = await _db.getFavouriteIds();
    if (_disposed) return;
    _favouriteIds = ids;
    notifyListeners();
  }

  /// Check if a hadith is favourited.
  bool isFavourite(String hadithId) => _favouriteIds.contains(hadithId);

  /// Load similar hadiths for the given hadith ID.
  Future<void> loadSimilarHadith(
    String hadithId, {
    bool alternate = false,
  }) async {
    final generation = ++_requestGeneration;
    _isLoading = true;
    _errorMessage = null;
    _results = [];
    notifyListeners();

    await _loadFavouriteIds();
    if (_disposed || generation != _requestGeneration) return;
    final ApiResult<List<Hadith>> result;
    if (alternate) {
      final alternative = await _api.getAlternateHadith(hadithId);
      result = alternative.isSuccess
          ? ApiResult.success([alternative.data!])
          : alternative.error == ApiError.notFound
          ? ApiResult.success([])
          : ApiResult.error(alternative.error!);
    } else {
      result = await _api.getSimilarHadith(hadithId);
    }
    if (_disposed || generation != _requestGeneration) return;

    if (result.isSuccess) {
      _results = result.data!;
      if (_results.isEmpty) {
        _errorMessage = 'noSimilar';
      }
    } else {
      _errorMessage = result.error!.arabicTitle;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load favourite IDs for checking.
  Future<void> _loadFavouriteIds() async {
    _favouriteIds = await _db.getFavouriteIds();
  }

  /// Toggle favourite status for a hadith.
  Future<String?> toggleFavourite(Hadith hadith) async {
    if (_favouriteIds.contains(hadith.id)) {
      final success = await _db.removeFavourite(hadith.id);
      if (success) {
        _favouriteIds.remove(hadith.id);
        notifyListeners();
        return null;
      } else {
        return 'فشل إزالة الحديث من المفضلة';
      }
    } else {
      final success = await _db.addFavourite(
        hadithId: hadith.id,
        hadithText: hadith.text,
        hadithInfo: hadith.formattedInfo,
        sharhId: hadith.sharhId,
        hasAlternate: hadith.hasAlternateHadithSahih,
      );
      if (success) {
        if (hadith.sharhId != null) {
          unawaited(
            ExplanationService().getExplanation(
              hadith.id,
              sharhId: hadith.sharhId,
            ),
          );
        }
        _favouriteIds.add(hadith.id);
        notifyListeners();
        return null;
      } else {
        return 'فشل إضافة الحديث للمفضلة';
      }
    }
  }

  /// Get sharh (explanation) for a hadith.
  Future<ApiResult<String>> getSharh(Hadith hadith) async {
    if (!hadith.hasSharhMetadata || hadith.sharhId == null) {
      return ApiResult.error(ApiError.notFound);
    }
    return _api.getSharh(hadith.sharhId!);
  }

  @override
  void dispose() {
    _disposed = true;
    _db.removeListener(_refreshFavouriteIds);
    super.dispose();
  }
}
