import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hadithsearcher/services/explanation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'concurrent explanation loads share a request and finish after cleanup',
    () async {
      final response = Completer<http.Response>();
      var requests = 0;
      await http.runWithClient(
        () async {
          final first = ExplanationService().getExplanation(
            'uncached',
            sharhId: '123',
          );
          final second = ExplanationService().getExplanation(
            'uncached',
            sharhId: '123',
          );
          response.complete(
            http.Response(
              '{"data":{"sharhMetadata":{"sharh":"explanation"}}}',
              200,
            ),
          );
          final results = await Future.wait([
            first,
            second,
          ]).timeout(const Duration(seconds: 2));
          expect(
            results.every((result) => result.data == 'explanation'),
            isTrue,
          );
          expect(requests, 1);
          await ExplanationService()
              .getExplanation('uncached', sharhId: '123')
              .timeout(const Duration(seconds: 2));
          expect(requests, 2);
        },
        () => MockClient((_) {
          requests++;
          return response.future;
        }),
      );
    },
  );
}
