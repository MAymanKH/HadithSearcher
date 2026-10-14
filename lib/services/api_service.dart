import 'dart:async';
import 'dart:convert';
import '../core/constants/app_config.dart';
import 'package:http/http.dart' as http;
import '../models/hadith.dart';
import '../models/search_params.dart';
import '../models/search_option.dart';
import 'telemetry/telemetry_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get _baseUrl => hadithApiBaseUrl;
  static const _timeout = Duration(seconds: 24);
  static const _shortTimeout = Duration(seconds: 8);

  Future<ApiResult<List<Hadith>>> searchHadith(SearchParams params) {
    final properties = <String, Object>{
      'query': params.keyword,
      'excluded_words': params.excludedWords,
      'query_length': params.keyword.trim().length,
      'has_excluded_words': params.excludedWords.trim().isNotEmpty,
      'page': params.page,
      'search_way': params.searchWay.name,
      'search_range': params.searchRange.name,
      'grade': params.searchGrade.name,
      'mohdith': params.searchMohdith.apiCode,
      'book': params.searchBook.apiCode,
    };
    if (params.page == 1) {
      TelemetryService.event('search_submitted', properties);
    }
    return _get(
      '/v1/site/hadith/search',
      operation: 'search',
      event: params.page == 1 ? 'search_completed' : 'pagination_completed',
      query: params.toQueryParams(),
      properties: properties,
      parse: _parseHadiths,
    );
  }

  Future<ApiResult<List<SearchOption>>> getFilterOptions(String kind) => _get(
    '/v1/data/$kind',
    operation: 'filter_catalog',
    event: 'filter_catalog_completed',
    parse: (json) => ApiResult.success(
      (json as List)
          .map((item) => SearchOption.fromJson(item as Map<String, dynamic>))
          .toList(),
    ),
  );

  Future<ApiResult<List<Hadith>>> getSimilarHadith(String hadithId) {
    TelemetryService.event('similar_hadith_requested', {'hadith_id': hadithId});
    return _get(
      '/v1/site/hadith/similar/$hadithId',
      operation: 'similar_hadith',
      event: 'similar_hadith_completed',
      properties: {'hadith_id': hadithId},
      parse: _parseHadiths,
    );
  }

  Future<ApiResult<String>> getSharh(String sharhId) {
    TelemetryService.event('explanation_requested', {'sharh_id': sharhId});
    return _get(
      '/v1/site/sharh/$sharhId',
      operation: 'explanation',
      event: 'explanation_completed',
      timeout: _shortTimeout,
      properties: {'sharh_id': sharhId},
      parse: (json) {
        final sharh = json['data']?['sharhMetadata']?['sharh'] as String?;
        return sharh == null || sharh.isEmpty
            ? ApiResult.error(ApiError.notFound)
            : ApiResult.success(sharh);
      },
    );
  }

  Future<ApiResult<Hadith>> getHadithById(String hadithId) => _get(
    '/v1/site/hadith/$hadithId',
    operation: 'hadith_metadata',
    event: 'hadith_metadata_completed',
    timeout: _shortTimeout,
    properties: {'hadith_id': hadithId},
    parse: (json) => json['data'] == null
        ? ApiResult.error(ApiError.notFound)
        : ApiResult.success(Hadith.fromJson(json['data'])),
  );

  ApiResult<List<Hadith>> _parseHadiths(dynamic json) {
    final metadata = json['metadata'] as Map<String, dynamic>;
    final hadiths = (json['data'] as List)
        .map((hadith) => Hadith.fromJson(hadith))
        .toList();
    final hasNextPage = metadata['hasNextPage'] as bool?;
    final totalPages = metadata['totalPages'] as num?;
    final page = metadata['page'] as num?;
    return ApiResult.success(
      hadiths,
      hasNextPage:
          hasNextPage ??
          (totalPages != null && page != null && page < totalPages),
    );
  }

  Future<ApiResult<T>> _get<T>(
    String path, {
    required String operation,
    required String event,
    required ApiResult<T> Function(dynamic) parse,
    Map<String, String>? query,
    Map<String, Object> properties = const {},
    Duration timeout = _timeout,
  }) async {
    final analytics = TelemetryService.instance?.analyticsEnabled ?? false;
    final diagnostics = TelemetryService.instance?.diagnosticsEnabled ?? false;
    final timer = Stopwatch()..start();
    int? statusCode;
    ApiResult<T> result;
    try {
      result = await TelemetryService.trace('api.$operation', () async {
        final url = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
        final response = await http.get(url).timeout(timeout);
        statusCode = response.statusCode;
        if (response.statusCode == 404) {
          return ApiResult<T>.error(ApiError.notFound);
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (diagnostics) {
            TelemetryService.report(
              StateError('HTTP failure'),
              StackTrace.current,
              'api.$operation.http_${response.statusCode}',
            );
          }
          return ApiResult<T>.error(ApiError.unknown);
        }
        return parse(jsonDecode(utf8.decode(response.bodyBytes)));
      });
    } on http.ClientException {
      result = ApiResult.error(ApiError.noConnection);
    } on TimeoutException {
      result = ApiResult.error(ApiError.timeout);
    } catch (error, stack) {
      if (diagnostics) TelemetryService.report(error, stack, 'api.$operation');
      result = ApiResult.error(ApiError.unknown);
    }
    final outcomeProperties = <String, Object>{
      'operation': operation,
      'outcome': result.error?.name ?? 'success',
      'duration_ms': timer.elapsedMilliseconds,
      if (statusCode != null) 'status_code': statusCode!,
      if (result.data is List) 'result_count': (result.data as List).length,
    };
    if (analytics) {
      TelemetryService.event(event, {...properties, ...outcomeProperties});
    }
    return result;
  }
}

/// Result wrapper for API calls.
class ApiResult<T> {
  final T? data;
  final ApiError? error;
  final bool? hasNextPage;

  ApiResult._({this.data, this.error, this.hasNextPage});

  factory ApiResult.success(T data, {bool? hasNextPage}) =>
      ApiResult._(data: data, hasNextPage: hasNextPage);
  factory ApiResult.error(ApiError error) => ApiResult._(error: error);

  bool get isSuccess => error == null;
  bool get isError => error != null;
}

/// API error types.
enum ApiError {
  noConnection,
  timeout,
  notFound,
  unknown;

  /// Arabic error title.
  String get arabicTitle {
    switch (this) {
      case ApiError.noConnection:
        return 'خطأ بالإتصال بالإنترنت';
      case ApiError.timeout:
        return 'نفذ الوقت';
      case ApiError.notFound:
        return 'لا توجد نتائج';
      case ApiError.unknown:
        return 'خطأ غير متوقع';
    }
  }

  /// Arabic error description.
  String get arabicDescription {
    switch (this) {
      case ApiError.noConnection:
        return 'تأكد من إتصالك بالإنترنت وأعد المحاولة';
      case ApiError.timeout:
        return 'تأكد من إتصالك بإنترنت مستقر وأعد المحاولة';
      case ApiError.notFound:
        return 'استخدم كلمات أو إعدادات أخرى';
      case ApiError.unknown:
        return 'حدث خطأ غير متوقع، حاول مرة أخرى';
    }
  }
}
