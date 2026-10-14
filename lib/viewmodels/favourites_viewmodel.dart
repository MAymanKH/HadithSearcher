import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/explanation_service.dart';

/// ViewModel for favourites view.
class FavouritesViewModel extends ChangeNotifier {
  FavouritesViewModel() {
    _db.addListener(_refreshFavourites);
  }
  final DatabaseService _db = DatabaseService();
  bool _disposed = false;

  List<FavouriteHadith> _favourites = [];
  bool _isLoading = true;

  /// List of favourited hadiths.
  List<FavouriteHadith> get favourites => _favourites;

  /// Whether data is loading.
  bool get isLoading => _isLoading;

  /// Whether favourites list is empty.
  bool get isEmpty => _favourites.isEmpty && !_isLoading;

  /// Whether there are favourites.
  bool get hasFavourites => _favourites.isNotEmpty;

  /// Load all favourites from database.
  Future<void> loadFavourites() async {
    _isLoading = true;
    notifyListeners();

    _favourites = await _db.getFavourites();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshFavourites() async {
    final favourites = await _db.getFavourites();
    if (_disposed) return;
    _favourites = favourites;
    notifyListeners();
  }

  /// Remove a hadith from favourites.
  Future<String?> removeFavourite(String hadithId) async {
    final success = await _db.removeFavourite(hadithId);
    if (success) {
      _favourites.removeWhere((f) => f.hadithId == hadithId);
      notifyListeners();
      return null;
    } else {
      return 'فشل إزالة الحديث من المفضلة';
    }
  }

  /// Get sharh (explanation) for a hadith.
  Future<ApiResult<String>> getSharh(String hadithId) =>
      ExplanationService().getExplanation(hadithId);

  @override
  void dispose() {
    _disposed = true;
    _db.removeListener(_refreshFavourites);
    super.dispose();
  }
}
