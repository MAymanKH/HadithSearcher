import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/models/search_params.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TelemetryService telemetry;
  late FakeBackend backend;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    telemetry = TelemetryService(
        preferences: await SharedPreferences.getInstance(), backend: backend);
    TelemetryService.instance = telemetry;
  });
  tearDown(() {
    TelemetryService.instance = null;
    telemetry.dispose();
  });

  test('API encodes a query correctly and reports success only with consent',
      () async {
    await telemetry.save(diagnostics: false, analytics: true);
    const query = 'حديث & test';
    final result = await http.runWithClient(
        () => ApiService().searchHadith(
              SearchParams(
                  keyword: query, excludedWords: 'exclude & word'),
            ),
        () => MockClient((request) async {
              expect(request.url.queryParameters['value'], query);
              expect(request.url.queryParameters['xclude'], 'exclude & word');
              return http.Response('{"metadata":{"length":0},"data":[]}', 200);
            }));
    expect(result.data, isEmpty);
    expect(backend.events, ['search_submitted', 'search_completed']);
    expect(backend.properties.last['query'], query);
    expect(backend.properties.last['result_count'], 0);
    expect(backend.properties.last['outcome'], 'success');
  });

  test('server errors are classified before decoding and reported to Sentry',
      () async {
    await telemetry.save(diagnostics: true, analytics: false);
    final result = await http.runWithClient(
        () => ApiService().searchHadith(
              SearchParams(keyword: 'query'),
            ),
        () => MockClient((_) async => http.Response('upstream failure', 502)));
    expect(result.error, ApiError.unknown);
    expect(backend.reports, ['api.search.http_502']);
    expect(backend.reportDetails.single['status_code'], 502);
    expect(backend.reportDetails.single.toString(), isNot(contains('query')));
    expect(backend.events, isEmpty);
  });

  test('an operation started before consent is not retroactively tracked',
      () async {
    final response = Completer<http.Response>();
    final result = http.runWithClient(
        () => ApiService().searchHadith(
              SearchParams(keyword: 'pre-consent-query'),
            ),
        () => MockClient((_) => response.future));
    await telemetry.save(diagnostics: true, analytics: true);
    response
        .complete(http.Response('{"metadata":{"length":0},"data":[]}', 200));
    await result;
    expect(backend.events, isEmpty);
    expect(backend.reports, isEmpty);
  });

  test('book details recover from a transient upstream failure', () async {
    var requests = 0;
    final result = await http.runWithClient(
      () => ApiService().getBookDetails('12'),
      () => MockClient(
        (_) async => ++requests == 1
            ? http.Response('{}', 500)
            : http.Response('{"data":null}', 200),
      ),
    );
    expect(result.error, ApiError.notFound);
    expect(requests, 2);
  });

  test('filter catalog retries a transient TLS handshake failure', () async {
    var requests = 0;
    final result = await http.runWithClient(
      () => ApiService().getFilterOptions('book'),
      () => MockClient((_) async {
        if (++requests == 1) throw const HandshakeException('TLS handshake');
        return http.Response('{"data":[]}', 200);
      }),
    );
    expect(result.data, isEmpty);
    expect(requests, 2);
  });
}
