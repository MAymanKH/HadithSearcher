import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class TrackedClient extends MockClient {
  TrackedClient(super.handler);
  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  for (final operation in ['explanation', 'similar', 'alternate']) {
    testWidgets('$operation accepts a response within the server deadline', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      final client = TrackedClient((_) => response.future);
      await http.runWithClient(() async {
        final api = ApiService();
        final Future<ApiResult<dynamic>> pending = switch (operation) {
          'explanation' => api.getSharh('123'),
          'similar' => api.getSimilarHadith('abc'),
          _ => api.getAlternateHadith('abc'),
        };
        ApiResult<dynamic>? result;
        unawaited(pending.then((value) => result = value));
        await tester.pump(const Duration(seconds: 45));
        expect(result, isNull);
        expect(client.closed, isFalse);
        response.complete(
          http.Response(switch (operation) {
            'explanation' =>
              '{"data":{"sharhMetadata":{"sharh":"explanation"}}}',
            'similar' => '{"metadata":{},"data":[]}',
            _ => '{"data":{"hadithId":"abc","hadith":"text"}}',
          }, 200),
        );
        await tester.pump();
        expect((await pending).isSuccess, isTrue);
        expect(client.closed, isTrue);
      }, () => client);
    });
  }

  testWidgets('timeout closes the client and a retry uses a fresh client', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final firstClient = TrackedClient((_) => response.future);
    await http.runWithClient(() async {
      final pending = ApiService().getSharh('123');
      await tester.pump(const Duration(seconds: 66));
      expect((await pending).error, ApiError.timeout);
      expect(firstClient.closed, isTrue);
      response.complete(http.Response('late', 200));
      await tester.pump();
    }, () => firstClient);
    final retryClient = TrackedClient(
      (_) async => http.Response(
        '{"data":{"sharhMetadata":{"sharh":"explanation"}}}',
        200,
      ),
    );
    await http.runWithClient(() async {
      expect((await ApiService().getSharh('123')).data, 'explanation');
      expect(retryClient.closed, isTrue);
    }, () => retryClient);
  });

  for (final status in [408, 504]) {
    test('HTTP $status is reported as a timeout', () async {
      await http.runWithClient(() async {
        expect((await ApiService().getSharh('123')).error, ApiError.timeout);
      }, () => MockClient((_) async => http.Response('', status)));
    });
  }
}
