import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<http.Response> retryGet(
  Future<http.Response> Function() request,
  Duration timeout, {
  Set<int> retryStatusCodes = const {500, 502, 503, 504},
}) async {
  const delay = Duration(milliseconds: 250);
  final elapsed = Stopwatch()..start();
  try {
    final response = await request().timeout(timeout);
    if (!retryStatusCodes.contains(response.statusCode) ||
        response.headers.containsKey('retry-after') ||
        timeout - elapsed.elapsed <= delay) {
      return response;
    }
  } on HandshakeException {
    if (timeout - elapsed.elapsed <= delay) rethrow;
    // Reconnect using the same TLS validation.
  }
  await Future<void>.delayed(delay);
  final remaining = timeout - elapsed.elapsed;
  if (remaining <= Duration.zero) throw TimeoutException('GET', timeout);
  return request().timeout(remaining);
}
