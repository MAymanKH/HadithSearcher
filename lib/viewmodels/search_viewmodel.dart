import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/localization.dart';
import '../l10n/app_localizations_ar.dart';
import '../models/hadith.dart';
import '../models/search_params.dart';
import '../models/search_option.dart';
import '../services/api_service.dart';
import '../services/filter_catalog_service.dart';
import '../services/database_service.dart';
import '../services/favourite_details_service.dart';

/// ViewModel for hadith search functionality.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel() {
    _db.addListener(_refreshFavouriteIds);
  }

  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();

  // Search state
  List<Hadith> _results = [];
  int? _resultTotal;
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
  List<String> get activeFilters =>
      localizedActiveFilters(AppLocalizationsAr());

  List<String> localizedActiveFilters(AppLocalizations l) => [
    if (_searchWay != SearchWay.anyWord) _searchWay.label(l),
    if (_searchRange != SearchRange.all) _searchRange.label(l),
    if (_specialist) l.specialists,
    for (final filter in SearchFilter.values)
      if (excludedOptions(filter).isNotEmpty ||
          (selectedOptions(filter).isNotEmpty &&
              !selectedOptions(filter).any((option) => option.apiCode == '0')))
        '${filter.label(l)}: ${selectionLabel(filter, l)}',
    if (_excludedWords.trim().isNotEmpty) l.excludedWords(_excludedWords),
  ];

  final _filters = <SearchFilter, List<SearchOption>>{};
  final _exclusions = <SearchFilter, List<SearchOption>>{};
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

  List<SearchOption> excludedOptions(SearchFilter filter) =>
      _exclusions[filter] ?? const [];

  String selectionLabel(
    SearchFilter filter, [
    AppLocalizations? localizations,
  ]) {
    final l = localizations ?? AppLocalizationsAr();
    final excluded = excludedOptions(filter);
    if (excluded.isNotEmpty) {
      final names = excluded
          .take(2)
          .map((option) => filter.optionLabel(option, l))
          .join(l.localeName == 'ar' ? '، ' : ', ');
      return l.allExcept(
        "$names${excluded.length > 2 ? ' +${excluded.length - 2}' : ''}",
      );
    }
    final selected = selectedOptions(filter);
    if (selected.isEmpty || selected.any((option) => option.apiCode == '0')) {
      return filter.optionLabel(filter.all, l);
    }
    final names = selected
        .take(2)
        .map((option) => filter.optionLabel(option, l))
        .join(l.localeName == 'ar' ? '، ' : ', ');
    return selected.length > 2 ? '$names +${selected.length - 2}' : names;
  }

  void setSelectedOptions(
    SearchFilter filter,
    List<SearchOption> options, {
    List<SearchOption> excluded = const [],
  }) {
    final uniqueExcluded = {
      for (final option in excluded)
        if (option.apiCode != '0') option.apiCode: option,
    };
    _exclusions[filter] = List.unmodifiable(
      uniqueExcluded.values.toList()
        ..sort((a, b) => a.apiCode.compareTo(b.apiCode)),
    );
    final all =
        uniqueExcluded.isNotEmpty ||
        options.any((option) => option.apiCode == '0');
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
    exclusions: _exclusions,
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
  int? get resultTotal =>
      _currentParams?.specialist == _specialist ? _resultTotal : null;
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

    final savedExclusions = prefs.getString('searchFilterExclusions');
    if (savedExclusions != null) {
      try {
        final decoded = jsonDecode(savedExclusions) as Map<String, dynamic>;
        for (final filter in SearchFilter.values) {
          final options = (decoded[filter.name] as List? ?? const [])
              .map(
                (item) => SearchOption.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          if (options.isNotEmpty) {
            setSelectedOptions(filter, [filter.all], excluded: options);
          }
        }
      } on FormatException {
        _exclusions.clear();
      } on TypeError {
        _exclusions.clear();
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
    _exclusions.clear();
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
    _resultTotal = null;
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
    _resultTotal = null;
    _hasMoreResults = true;
    notifyListeners();
    for (final filter in SearchFilter.values) {
      final selected = selectedOptions(filter);
      if (filter.exclusionQueryKey == null || selected.length < 100) continue;
      final catalog = await _catalogs.load(filter);
      if (generation != _searchGeneration) return;
      if (catalog.isSuccess) {
        final options = catalog.data!
            .where((option) => option.apiCode != '0')
            .toList();
        final codes = selected.map((option) => option.apiCode).toSet();
        final catalogCodes = options.map((option) => option.apiCode).toSet();
        if (selected.length > options.length / 2 &&
            codes.every(catalogCodes.contains)) {
          setSelectedOptions(
            filter,
            [filter.all],
            excluded: options
                .where((option) => !codes.contains(option.apiCode))
                .toList(),
          );
          await saveAdvancedPrefs();
        }
      }
    }
    if (generation != _searchGeneration) return;
    _currentParams = _params(keyword);
    final result = await _loadMatchingPage(_currentParams!, generation);
    if (generation != _searchGeneration || result == null) return;

    if (result.isSuccess) {
      _results = result.data!;
      _resultTotal = result.totalCount;
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

    final result = await _loadMatchingPage(params, generation, retry: true);
    if (generation != _searchGeneration || result == null) return;
    if (result.isSuccess) {
      _results.addAll(result.data!);
      _hasMoreResults = result.hasNextPage ?? false;
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<ApiResult<List<Hadith>>?> _loadMatchingPage(
    SearchParams params,
    int generation, {
    bool retry = false,
  }) async {
    while (generation == _searchGeneration) {
      var result = await _api.searchHadith(params);
      if (generation != _searchGeneration) return null;
      if (retry && result.isError) {
        result = await _api.searchHadith(params);
        if (generation != _searchGeneration) return null;
      }
      _currentParams = params;
      if (result.isError ||
          result.data!.isNotEmpty ||
          params.exclusions.values.every((options) => options.isEmpty) ||
          result.hasNextPage != true) {
        return result;
      }
      params = params.nextPage();
    }
    return null;
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
        hadith: hadith,
        hadithId: hadith.id,
        hadithText: hadith.text,
        hadithInfo: hadith.formattedInfo,
        sharhId: hadith.sharhId,
        hasAlternate: hadith.hasAlternateHadithSahih,
      );
      if (success) {
        unawaited(FavouriteDetailsService().saveOffline(hadith));
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
        'searchFilterExclusions',
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
    await prefs.setString(
      'searchFilterExclusions',
      jsonEncode({
        for (final entry in _exclusions.entries)
          if (entry.value.isNotEmpty)
            entry.key.name: entry.value
                .map((option) => option.toJson())
                .toList(),
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
