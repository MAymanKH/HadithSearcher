import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith.dart';
import '../models/search_params.dart';
import '../models/search_option.dart';
import '../services/api_service.dart';
import '../services/filter_catalog_service.dart';
import '../services/database_service.dart';
import '../services/explanation_service.dart';

/// ViewModel for hadith search functionality.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel() {
    _db.addListener(_refreshFavouriteIds);
  }

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
  int _lastShareRevision = 0;
  bool _initialized = false;
  bool _disposed = false;
  final _catalogs = FilterCatalogService();
  List<String> get activeFilters => [
    if (_searchWay != SearchWay.anyWord) _searchWay.arabicName,
    if (_searchRange != SearchRange.all) _searchRange.arabicName,
    if (_specialist) 'للمتخصصين',
    for (final filter in SearchFilter.values)
      if (selectedOptions(filter).isNotEmpty &&
          !selectedOptions(filter).any((option) => option.apiCode == '0'))
        '${filter.arabicName}: ${selectionLabel(filter)}',
    if (_excludedWords.trim().isNotEmpty) 'استبعاد: $_excludedWords',
  ];

  final _filters = <SearchFilter, List<SearchOption>>{};
  bool _specialist = false;
  bool _showActiveFilters = true;
  bool get showActiveFilters => _showActiveFilters;

  Future<void> setShowActiveFilters(bool value) async {
    _showActiveFilters = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showActiveFilters', value);
  }

  bool get specialist => _specialist;

  List<SearchOption> selectedOptions(SearchFilter filter) =>
      _filters[filter] ?? const [];

  String selectionLabel(SearchFilter filter) {
    final selected = selectedOptions(filter);
    if (selected.isEmpty || selected.any((option) => option.apiCode == '0')) {
      return filter.all.arabicName;
    }
    final names = selected
        .take(2)
        .map((option) => option.arabicName)
        .join('، ');
    return selected.length > 2 ? '$names +${selected.length - 2}' : names;
  }

  void setSelectedOptions(SearchFilter filter, List<SearchOption> options) {
    final all = options.any((option) => option.apiCode == '0');
    final unique = {
      for (final option in options)
        if (option.apiCode != '0') option.apiCode: option,
    };
    _filters[filter] = all
        ? List.unmodifiable([filter.all])
        : List.unmodifiable(
            unique.values.toList()
              ..sort((a, b) => a.apiCode.compareTo(b.apiCode)),
          );
    notifyListeners();
  }

  void setSpecialist(bool value) {
    _specialist = value;
    notifyListeners();
  }

  SearchParams _params(String keyword) => SearchParams(
    keyword: keyword,
    searchWay: _searchWay,
    searchRange: _searchRange,
    filters: _filters,
    specialist: _specialist,
    excludedWords: _excludedWords,
  );

  // Advanced search state
  bool _isAdvancedSearchOpen = false;
  SearchWay _searchWay = SearchWay.anyWord;
  SearchRange _searchRange = SearchRange.all;
  String _excludedWords = '';
  bool _saveAdvancedSettings = true;
  String _searchQuery = '';

  String? _initialFilterQuery;

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
  String get excludedWords => _excludedWords;
  bool get saveAdvancedSettings => _saveAdvancedSettings;
  String get searchQuery => _searchQuery;
  int get resultRevision => _searchGeneration;

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

    _showActiveFilters = prefs.getBool('showActiveFilters') ?? true;
    _saveAdvancedSettings = prefs.getBool('advancedSaveCheckbox') ?? true;
    await prefs.remove('searchQuery');
    await prefs.remove('recentSearches');
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

    _specialist = prefs.getBool('searchSpecialist') ?? false;
    final savedFilters = prefs.getString('searchFilters');
    if (savedFilters != null) {
      try {
        final decoded = jsonDecode(savedFilters) as Map<String, dynamic>;
        for (final filter in SearchFilter.values) {
          final saved = decoded[filter.name] as List? ?? const [];
          setSelectedOptions(
            filter,
            saved
                .map(
                  (item) => SearchOption.fromJson(item as Map<String, dynamic>),
                )
                .toList(),
          );
        }
      } on FormatException {
        _filters.clear();
      } on TypeError {
        _filters.clear();
      }
    } else {
      for (final entry in {
        SearchFilter.grade: 'searchGrade',
        SearchFilter.scholar: 'searchMohdith',
        SearchFilter.book: 'searchBook',
        SearchFilter.narrator: 'searchRawi',
      }.entries) {
        final option = _restoreOption(
          prefs,
          entry.value,
          entry.key.fallbackOptions,
        );
        setSelectedOptions(entry.key, option.apiCode == '0' ? [] : [option]);
      }
    }

    _excludedWords = prefs.getString('searchExcludedWords') ?? '';
    notifyListeners();
  }

  SearchOption _restoreOption(
    SharedPreferences prefs,
    String key,
    List<SearchOption> options,
  ) {
    final saved = prefs.getString(key);
    return options.firstWhere(
      (option) =>
          option.apiCode == saved ||
          option.arabicName == saved ||
          (saved == 'الإمام المالك' && option.apiCode == '179'),
      orElse: () => prefs.containsKey('$key.label')
          ? SearchOption(saved!, prefs.getString('$key.label')!)
          : options.first,
    );
  }

  Future<ApiResult<List<SearchOption>>> loadFilterOptions(
    SearchFilter filter,
  ) => _catalogs.load(filter);

  void resetFilters() {
    _searchWay = SearchWay.anyWord;
    _searchRange = SearchRange.all;
    _filters.clear();
    _specialist = false;
    _excludedWords = '';
    notifyListeners();
  }

  void prepareSharedSearch(String text, int revision) {
    if (revision == _lastShareRevision) return;
    _lastShareRevision = revision;
    _searchGeneration++;
    _searchQuery = text;
    _results = [];
    _currentParams = null;
    _errorMessage = null;
    _isLoading = false;
    _isLoadingMore = false;
    _isAdvancedSearchOpen = false;
    notifyListeners();
  }

  /// Load favourite hadith IDs for checking.
  Future<void> _loadFavouriteIds() async {
    _favouriteIds = await _db.getFavouriteIds();
  }

  Future<void> _refreshFavouriteIds() async {
    final ids = await _db.getFavouriteIds();
    if (_disposed) return;
    _favouriteIds = ids;
    notifyListeners();
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

    keyword = keyword.trim();
    _searchQuery = keyword;
    final generation = ++_searchGeneration;
    _isLoading = true;
    _isLoadingMore = false;
    _errorMessage = null;
    _results = [];
    _hasMoreResults = true;
    _currentParams = _params(keyword);

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
    _initialFilterQuery = _params('').toQueryString();
  }

  bool hasSettingsChanged() =>
      _initialFilterQuery != _params('').toQueryString();

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
    for (final key in [
      'searchGrade',
      'searchMohdith',
      'searchMohdith.label',
      'searchBook',
      'searchBook.label',
      'searchRawi',
      'searchRawi.label',
    ]) {
      await prefs.remove(key);
    }
    if (!_saveAdvancedSettings) {
      for (final key in [
        'searchWay',
        'searchRange',
        'searchFilters',
        'searchSpecialist',
        'searchExcludedWords',
      ]) {
        await prefs.remove(key);
      }
      return;
    }
    await prefs.setString('searchWay', _searchWay.arabicName);
    await prefs.setString('searchRange', _searchRange.arabicName);
    await prefs.setBool('searchSpecialist', _specialist);
    await prefs.setString(
      'searchFilters',
      jsonEncode({
        for (final entry in _filters.entries)
          entry.key.name: entry.value.map((option) => option.toJson()).toList(),
      }),
    );
    await prefs.setString('searchExcludedWords', _excludedWords);
  }

  @override
  void dispose() {
    _disposed = true;
    _db.removeListener(_refreshFavouriteIds);
    _searchGeneration++;
    super.dispose();
  }

  /// Clear error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
