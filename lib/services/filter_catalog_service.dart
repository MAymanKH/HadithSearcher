import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_option.dart';
import 'api_service.dart';

class FilterCatalogService {
  static const cacheLifetime = Duration(days: 7);
  final _options = <SearchFilter, List<SearchOption>>{};
  final _pending = <SearchFilter, Future<ApiResult<List<SearchOption>>>>{};

  Future<ApiResult<List<SearchOption>>> load(SearchFilter filter) {
    final options = _options[filter];
    if (options != null) return Future.value(ApiResult.success(options));
    return _pending.putIfAbsent(
      filter,
      () => _load(filter).whenComplete(() {
        _pending.remove(filter);
      }),
    );
  }

  Future<ApiResult<List<SearchOption>>> _load(SearchFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'filterCatalog.${filter.endpoint}';
    List<SearchOption>? cached;
    final body = prefs.getString(key);
    if (body != null) {
      try {
        final decoded = await compute(SearchOption.decodeCatalog, body);
        if (decoded.any((option) => option.apiCode != '0')) {
          cached = _canonicalize(filter, decoded);
        }
      } on FormatException {
        cached = null;
      } on TypeError {
        cached = null;
      } on NoSuchMethodError {
        cached = null;
      }
    }
    final savedAt = prefs.getInt('$key.savedAt');
    if (cached != null && savedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (age >= 0 && age < cacheLifetime.inMilliseconds) {
        _options[filter] = cached;
        return ApiResult.success(cached);
      }
    }

    final result = await ApiService().getFilterOptions(filter.endpoint);
    if (result.isSuccess &&
        result.data!.any((option) => option.apiCode != '0')) {
      final options = _canonicalize(filter, result.data!);
      _options[filter] = options;
      await prefs.setString(
        key,
        await compute(SearchOption.encodeCatalog, options),
      );
      await prefs.setInt('$key.savedAt', DateTime.now().millisecondsSinceEpoch);
      return ApiResult.success(options);
    }
    if (cached != null) {
      // Keep stale options usable offline, but retry the API next time.
      return ApiResult.success(cached);
    }
    return ApiResult.error(result.error ?? ApiError.notFound);
  }

  List<SearchOption> _canonicalize(
    SearchFilter filter,
    List<SearchOption> options,
  ) => {
    '0': filter.all,
    for (final option in options)
      if (option.apiCode != '0') option.apiCode: option,
  }.values.toList();
}
