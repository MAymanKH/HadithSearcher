import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/services/telemetry/posthog_analytics.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const previous = '0055d61d-2f4f-4b9d-acd4-17763eb67cd7';
  late SharedPreferences preferences;
  late DateTime now;
  late List<Map<String, dynamic>> batches;
  late Future<http.Response> Function() respond;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 11, 19, 10);
    batches = [];
    respond = () async => http.Response('{"status":1}', 200);
  });

  PostHogAnalytics create() => PostHogAnalytics(
    preferences: preferences,
    host: Uri.parse('https://example.test/analytics/'),
    token: 'phc_test',
    now: () => now,
    context: const {r'$device_type': 'Mobile', r'$app_version': '3.0.4'},
    createClient: () => MockClient((request) {
      expect(request.url.path, '/analytics/batch/');
      batches.add(jsonDecode(request.body) as Map<String, dynamic>);
      return respond();
    }),
  );

  List<Map<String, dynamic>> events(int index) =>
      (batches[index]['batch'] as List).cast<Map<String, dynamic>>();

  test('posts standard mobile views and preserves custom insights', () async {
    final client = create();
    addTearDown(client.stop);
    await client.capture('before_consent', {});
    await client.flush();
    expect(batches, isEmpty);

    await client.start(previousId: previous);
    await client.capture('screen_viewed', {'screen': 'search'});
    now = now.add(const Duration(minutes: 2));
    await client.capture('search_completed', {'result_count': 4});
    await client.flush();
    final batch = events(0);
    expect(batch.map((e) => e['event']), [
      r'$screen',
      'screen_viewed',
      'search_completed',
    ]);
    expect(batch.first['properties'][r'$screen_name'], 'search');
    expect(batch[1]['properties']['screen'], 'search');
    expect(batch.last['properties']['result_count'], 4);
    final session = batch.first['properties'][r'$session_id'] as String;
    expect(Uuid.isValidUUID(fromString: session), isTrue);
    expect(session[14], '7');
    final sessionMillis = int.parse(
      session.replaceAll('-', '').substring(0, 12),
      radix: 16,
    );
    expect(
      sessionMillis,
      DateTime.utc(2026, 11, 19, 10).millisecondsSinceEpoch,
    );
    for (final event in batch) {
      expect(event['distinct_id'], previous);
      expect(event['properties'][r'$session_id'], session);
      expect(event['properties'], isNot(contains(r'$geoip_disable')));
      expect(event['properties'][r'$process_person_profile'], isFalse);
      expect(event['properties'][r'$device_type'], 'Mobile');
      expect(event['properties'][r'$app_version'], '3.0.4');
    }

    now = now.add(const Duration(minutes: 30));
    await client.capture('screen_viewed', {'screen': 'settings'});
    await client.flush();
    expect(events(1).first['properties'][r'$session_id'], isNot(session));
  });

  test('replays durable events once, under their original identity', () async {
    final first = create();
    await first.start(previousId: previous);
    respond = () async => http.Response('busy', 429);
    await first.capture('search_completed', {'result_count': 1});
    await first.flush();
    final pending = events(0).single;
    await first.flush();
    expect(batches, hasLength(1));

    // Restore the bytes a new process sees, before the first process cleans up.
    final stored = preferences.getString('posthog_http_v1');
    await first.stop();
    await preferences.setString('posthog_http_v1', stored!);
    respond = () async => http.Response('{"status":1}', 200);
    final restored = create();
    addTearDown(restored.stop);
    await restored.start();
    await restored.flush();
    expect(events(1).single, pending);
    expect(restored.distinctId, previous);
    await restored.flush();
    expect(batches, hasLength(2));
  });

  test('withdrawal drops pending events and isolates a late upload', () async {
    final client = create();
    addTearDown(client.stop);
    final oldReply = Completer<http.Response>();
    final oldRequestStarted = Completer<void>();
    await client.start();
    final oldId = client.distinctId;
    respond = () {
      oldRequestStarted.complete();
      return oldReply.future;
    };
    await client.capture('old_in_flight', {});
    final oldUpload = client.flush();
    await oldRequestStarted.future;
    await client.capture('old_pending', {});
    await client.stop();
    expect(preferences.getString('posthog_http_v1'), isNull);
    await client.capture('disabled', {});

    respond = () async => http.Response('{"status":1}', 200);
    await client.start();
    expect(client.distinctId, isNot(oldId));
    await client.capture('new_event', {});
    oldReply.complete(http.Response('{"status":1}', 200));
    await oldUpload;
    await client.flush();
    expect(batches, hasLength(2));
    expect(events(1).map((event) => event['event']), ['new_event']);
  });
}
