import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith.dart';
import '../models/search_params.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

/// ViewModel for hadith search functionality.
class SearchViewModel extends ChangeNotifier {
  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();

  // Search state
  List<Hadith> _results = [];
  Set<String> _favouriteIds = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreResults = true;
  String? _errorMessage;
  SearchParams? _currentParams;
  int _searchGeneration = 0;
  bool _initialized = false;

  // Advanced search state
  bool _isAdvancedSearchOpen = false;
  SearchWay _searchWay = SearchWay.anyWord;
  SearchRange _searchRange = SearchRange.all;
  SearchGrade _searchGrade = SearchGrade.all;
  SearchMohdith _searchMohdith = SearchMohdith.all;
  SearchBook _searchBook = SearchBook.all;
  String _excludedWords = '';
  bool _saveAdvancedSettings = true;
  String _searchQuery = '';

  // Initial state for change detection
  SearchWay? _initialSearchWay;
  SearchRange? _initialSearchRange;
  SearchGrade? _initialSearchGrade;
  SearchMohdith? _initialSearchMohdith;
  SearchBook? _initialSearchBook;
  String? _initialExcludedWords;

  // Getters
  List<Hadith> get results => _results;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreResults => _hasMoreResults;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _results.isEmpty && !_isLoading;
  bool get hasResults => _results.isNotEmpty;

  // Advanced search getters
  bool get isAdvancedSearchOpen => _isAdvancedSearchOpen;
  SearchWay get searchWay => _searchWay;
  SearchRange get searchRange => _searchRange;
  SearchGrade get searchGrade => _searchGrade;
  SearchMohdith get searchMohdith => _searchMohdith;
  SearchBook get searchBook => _searchBook;
  String get excludedWords => _excludedWords;
  bool get saveAdvancedSettings => _saveAdvancedSettings;
  String get searchQuery => _searchQuery;

  /// Initialize by loading saved preferences.
  Future<void> init() async {
    if (!_initialized) {
      await _loadAdvancedPrefs();
      _initialized = true;
    }
    await _loadFavouriteIds();
    notifyListeners();
  }

  /// Load saved advanced search preferences.
  Future<void> _loadAdvancedPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _saveAdvancedSettings = prefs.getBool('advancedSaveCheckbox') ?? true;
    _searchQuery = prefs.getString('searchQuery') ?? '';
    if (!_saveAdvancedSettings) {
      notifyListeners();
      return;
    }

    final wayStr = prefs.getString('searchWay');
    if (wayStr != null) {
      _searchWay = SearchWay.fromArabic(wayStr);
    }

    final rangeStr = prefs.getString('searchRange');
    if (rangeStr != null) {
      _searchRange = SearchRange.fromArabic(rangeStr);
    }

    final gradeStr = prefs.getString('searchGrade');
    if (gradeStr != null) {
      _searchGrade = SearchGrade.fromArabic(gradeStr);
    }

    final mohdithStr = prefs.getString('searchMohdith');
    if (mohdithStr != null) {
      _searchMohdith = SearchMohdith.fromArabic(mohdithStr);
    }

    final bookStr = prefs.getString('searchBook');
    if (bookStr != null) {
      _searchBook = SearchBook.fromArabic(bookStr);
    }

    _excludedWords = prefs.getString('searchExcludedWords') ?? '';
    notifyListeners();
  }

  /// Load favourite hadith IDs for checking.
  Future<void> _loadFavouriteIds() async {
    _favouriteIds = await _db.getFavouriteIds();
  }

  /// Check if a hadith is favourited.
  bool isFavourite(String hadithId) => _favouriteIds.contains(hadithId);

  /// Search for hadiths with given keyword.
  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      _errorMessage = 'emptySearch';
      notifyListeners();
      return;
    }

    final generation = ++_searchGeneration;
    _isLoading = true;
    _isLoadingMore = false;
    _errorMessage = null;
    _results = [];
    _hasMoreResults = true;
    _currentParams = SearchParams(
      keyword: keyword,
      page: 1,
      searchWay: _searchWay,
      searchRange: _searchRange,
      searchGrade: _searchGrade,
      searchMohdith: _searchMohdith,
      searchBook: _searchBook,
      excludedWords: _excludedWords,
    );

    notifyListeners();
    final result = await _api.searchHadith(_currentParams!);
    if (generation != _searchGeneration) return;

    if (result.isSuccess) {
      _results = result.data!;
      _hasMoreResults = result.hasNextPage ?? false;
      await _loadFavouriteIds();
      if (generation != _searchGeneration) return;

      if (_results.isEmpty) {
        _errorMessage = 'noResults';
      }
    } else {
      _errorMessage = result.error!.arabicTitle;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load more results (pagination).
  Future<void> loadMore() async {
    if (_isLoading ||
        _isLoadingMore ||
        !_hasMoreResults ||
        _currentParams == null) {
      return;
    }
    final generation = _searchGeneration;
    final params = _currentParams!.nextPage();
    _isLoadingMore = true;
    notifyListeners();

    var result = await _api.searchHadith(params);
    if (generation != _searchGeneration) return;
    if (result.isError) {
      result = await _api.searchHadith(params);
      if (generation != _searchGeneration) return;
    }

    // After two failures, the next load moves past this page silently.
    _currentParams = params;
    if (result.isSuccess) {
      _results.addAll(result.data!);
      _hasMoreResults = result.hasNextPage ?? false;
    }
    _isLoadingMore = false;
    notifyListeners();
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
      );
      if (success) {
        _favouriteIds.add(hadith.id);
        notifyListeners();
        return null;
      } else {
        return 'فشل إضافة الحديث للمفضلة';
      }
    }
  }

  /// Toggle advanced search panel.
  void toggleAdvancedSearch() {
    if (!_isAdvancedSearchOpen) {
      // Opening the panel - save initial state
      _saveInitialState();
    }
    _isAdvancedSearchOpen = !_isAdvancedSearchOpen;
    notifyListeners();
  }

  /// Save the initial state of advanced search settings.
  void _saveInitialState() {
    _initialSearchWay = _searchWay;
    _initialSearchRange = _searchRange;
    _initialSearchGrade = _searchGrade;
    _initialSearchMohdith = _searchMohdith;
    _initialSearchBook = _searchBook;
    _initialExcludedWords = _excludedWords;
  }

  /// Check if advanced search settings have changed.
  bool hasSettingsChanged() {
    return _initialSearchWay != _searchWay ||
        _initialSearchRange != _searchRange ||
        _initialSearchGrade != _searchGrade ||
        _initialSearchMohdith != _searchMohdith ||
        _initialSearchBook != _searchBook ||
        _initialExcludedWords != _excludedWords;
  }

  /// Close advanced search panel.
  void closeAdvancedSearch() {
    _isAdvancedSearchOpen = false;
    notifyListeners();
  }

  // Advanced search setters
  void setSearchWay(SearchWay value) {
    _searchWay = value;
    notifyListeners();
  }

  void setSearchRange(SearchRange value) {
    _searchRange = value;
    notifyListeners();
  }

  void setSearchGrade(SearchGrade value) {
    _searchGrade = value;
    notifyListeners();
  }

  void setSearchMohdith(SearchMohdith value) {
    _searchMohdith = value;
    notifyListeners();
  }

  void setSearchBook(SearchBook value) {
    _searchBook = value;
    notifyListeners();
  }

  void setExcludedWords(String value) {
    _excludedWords = value;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    // Don't notify listeners to avoid rebuild during typing
  }

  Future<void> setSaveAdvancedSettings(bool value) async {
    _saveAdvancedSettings = value;
    notifyListeners();
    await saveAdvancedPrefs();
  }

  /// Save advanced search settings if enabled.
  Future<void> saveAdvancedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('advancedSaveCheckbox', _saveAdvancedSettings);
    await prefs.setString('searchQuery', _searchQuery);
    if (!_saveAdvancedSettings) {
      for (final key in [
        'searchWay',
        'searchRange',
        'searchGrade',
        'searchMohdith',
        'searchBook',
        'searchExcludedWords',
      ]) {
        await prefs.remove(key);
      }
      return;
    }
    await prefs.setString('searchWay', _searchWay.arabicName);
    await prefs.setString('searchRange', _searchRange.arabicName);
    await prefs.setString('searchGrade', _searchGrade.arabicName);
    await prefs.setString('searchMohdith', _searchMohdith.arabicName);
    await prefs.setString('searchBook', _searchBook.arabicName);
    await prefs.setString('searchExcludedWords', _excludedWords);
  }

  @override
  void dispose() {
    _searchGeneration++;
    super.dispose();
  }

  /// Clear error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
