import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/services/telemetry/posthog_replay.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('falls back to PNG and preserves taps on unchanged frames', () async {
    final uploads = <List<dynamic>>[];
    final replay = PostHogReplay(
      'phc_test',
      Uri.parse('http://127.0.0.1'),
      encodeWebp: (_) async => throw StateError('Encoder failed'),
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"sessionRecording":true}', 200);
        }
        expect(request.url.path, '/s/');
        expect(request.headers['content-encoding'], 'gzip');
        final body = jsonDecode(
          utf8.decode(gzip.decode(request.bodyBytes)),
        ) as List<dynamic>;
        uploads.add(body);
        return http.Response('', 200);
      }),
    );
    addTearDown(replay.close);

    final png = Uint8List.fromList([1, 2, 3]);
    final now = DateTime.utc(2026);
    Future<void> capture({Offset? tap}) => replay.capture(
      now: now,
      distinctId: 'test-device',
      sessionId: '00000000-0000-7000-8000-000000000001',
      screen: 'search',
      captureFrame: () async => (size: const Size(360, 800), png: png),
      tap: tap,
    );
    await capture();
    await capture();
    await capture(tap: const Offset(12, 30));

    expect(uploads, hasLength(2));
    final frames =
        uploads.first.single['properties'][r'$snapshot_data'] as List;
    expect(frames.map((frame) => frame['type']), [4, 2]);
    final wireframes = frames.last['data']['wireframes'] as List;
    expect(wireframes.single['base64'], 'data:image/png;base64,AQID');
    final tapFrames =
        uploads.last.single['properties'][r'$snapshot_data'] as List;
    expect(tapFrames.single['type'], 3);
    expect(tapFrames.single['timestamp'], now.millisecondsSinceEpoch);
    expect(tapFrames.single['data']['x'], 12);
    expect(tapFrames.single['data']['y'], 30);
  });
}
