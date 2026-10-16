import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_option.dart';
import 'api_service.dart';

class FilterCatalogService {
  static const cacheLifetime = Duration(days: 7);
  final _options = <String, List<SearchOption>>{};
  final _pending = <String, Future<ApiResult<List<SearchOption>>>>{};

  Future<ApiResult<List<SearchOption>>> load(SearchFilter filter) =>
      loadCatalog(filter.endpoint);

  Future<ApiResult<List<SearchOption>>> loadCatalog(String endpoint) {
    final options = _options[endpoint];
    if (options != null) return Future.value(ApiResult.success(options));
    return _pending.putIfAbsent(
      endpoint,
      () => _load(endpoint).whenComplete(() {
        _pending.remove(endpoint);
      }),
    );
  }

  Future<ApiResult<List<SearchOption>>> _load(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'filterCatalog.$endpoint';
    List<SearchOption>? cached;
    final body = prefs.getString(key);
    if (body != null) {
      try {
        final decoded = await compute(SearchOption.decodeCatalog, body);
        if (decoded.any((option) => option.apiCode != '0')) {
          cached = decoded;
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
        _options[endpoint] = cached;
        return ApiResult.success(cached);
      }
    }

    final result = await ApiService().getFilterOptions(endpoint);
    if (result.isSuccess &&
        result.data!.any((option) => option.apiCode != '0')) {
      final options = result.data!;
      _options[endpoint] = options;
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
}
