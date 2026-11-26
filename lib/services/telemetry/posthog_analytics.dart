import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import 'posthog_replay.dart';
import 'telemetry_service.dart';

class PostHogAnalytics with WidgetsBindingObserver {
  static const _storageKey = 'posthog_http_v1';
  static const _batchSize = 20;
  static const _queueLimit = 200;
  static const _flushInterval = Duration(minutes: 1);
  static const _sessionIdleLimit = Duration(minutes: 30);
  static const _sessionMaxAge = Duration(days: 1);

  final SharedPreferences _preferences;
  final String _token;
  final Uri _host;
  final Uri _batchUrl;
  final Map<String, Object> _context;
  final DateTime Function() _now;
  final http.Client Function() _createClient;
  final List<Map<String, dynamic>> _queue = [];
  Future<void> _writes = Future.value();
  Future<void>? _sending;
  http.Client? _client;
  Timer? _timer;
  String? _distinctId;
  String? _sessionId;
  DateTime? _sessionStart;
  DateTime? _lastEvent;
  DateTime? _retryAt;
  int _failures = 0;
  int _generation = 0;
  bool _background = false;
  PostHogReplay? _replay;
  String? _screen;

  PostHogAnalytics({
    required this._preferences,
    required this._token,
    required Uri host,
    required Map<String, Object> context,
    DateTime Function()? now,
    http.Client Function()? createClient,
  }) : _host = host,
       _batchUrl = host.replace(
         path: '${host.path.replaceFirst(RegExp(r'/+$'), '')}/batch/',
       ),
       _context = Map.unmodifiable(context),
       _now = now ?? DateTime.now,
       _createClient = createClient ?? http.Client.new;

  String? get distinctId => _distinctId;

  Future<void> start({String? previousId}) async {
    if (_distinctId != null) return;
    await _writes;
    _restore();
    _distinctId ??= previousId ?? const Uuid().v4();
    try {
      await _persist();
      _client = _createClient();
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(_flushInterval, (_) => unawaited(flush()));
      unawaited(flush());
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _generation++;
    _distinctId = null;
    _queue.clear();
    _sessionId = null;
    _sessionStart = _lastEvent = _retryAt = null;
    _failures = 0;
    _background = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _client?.close();
    _client = null;
    _replay?.close();
    _replay = null;
    _screen = null;
    _sending = null;
    await _persist();
  }

  // Also clear persisted events if consent was disabled before this process
  // created an analytics client.
  static Future<void> clearStored(SharedPreferences preferences) async {
    if (!await preferences.remove(_storageKey)) {
      throw StateError('Could not clear analytics storage');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_background) {
      _background = true;
      final lastEvent = _lastEvent;
      final sessionStart = _sessionStart;
      final now = _now();
      if (lastEvent != null &&
          sessionStart != null &&
          !now.isBefore(lastEvent) &&
          now.difference(lastEvent) < _sessionIdleLimit &&
          now.difference(sessionStart) < _sessionMaxAge) {
        unawaited(_recordLifecycle('app_backgrounded'));
      } else {
        unawaited(flush());
      }
    } else if (state == AppLifecycleState.resumed && _background) {
      _background = false;
      unawaited(_recordLifecycle('app_foregrounded'));
    }
  }

  Future<void> _recordLifecycle(String event) async {
    try {
      await capture(event, const {});
      await flush();
    } catch (_) {
      // Analytics must not interrupt app lifecycle handling.
    }
  }

  Future<void> capture(String name, Map<String, Object> properties) async {
    if (_client == null) return;
    final generation = _generation;
    final now = _now().toUtc();
    if (_sessionId == null ||
        now.isBefore(_lastEvent!) ||
        now.difference(_lastEvent!) >= _sessionIdleLimit ||
        now.difference(_sessionStart!) >= _sessionMaxAge) {
      _sessionStart = now;
      _sessionId = _uuidAt(now);
    }
    _lastEvent = now;

    final screen = properties['screen'];
    // Keep the existing event for saved insights and add PostHog's mobile
    // screen event for built-in reports.
    if (name == 'screen_viewed' && screen is String && screen.isNotEmpty) {
      _screen = screen;
      _enqueue(r'$screen', {r'$screen_name': screen}, now);
    }
    _enqueue(name, properties, now);
    await _persist();
    if (generation == _generation && _queue.length >= _batchSize) {
      unawaited(flush());
    }
  }

  Future<void> captureReplay(
    CaptureReplayFrame captureFrame,
    Offset? tap,
  ) async {
    final id = _distinctId;
    final session = _sessionId;
    final lastEvent = _lastEvent;
    final now = _now().toUtc();
    if (_client == null ||
        _background ||
        id == null ||
        session == null ||
        lastEvent == null ||
        now.difference(lastEvent) >= _sessionIdleLimit ||
        now.difference(_sessionStart!) >= _sessionMaxAge) {
      return;
    }
    final replay = _replay ??= PostHogReplay(
      _token,
      _host,
      client: _createClient(),
    );
    await replay.capture(
      now: now,
      distinctId: id,
      sessionId: session,
      screen: _screen ?? 'app',
      captureFrame: captureFrame,
      tap: tap,
    );
  }

  void _enqueue(String name, Map<String, Object> properties, DateTime now) {
    final event = <String, dynamic>{
      'event': name,
      'distinct_id': _distinctId!,
      'uuid': _uuidAt(now),
      'timestamp': now.toIso8601String(),
      'properties': {
        ...properties,
        ..._context,
        r'$session_id': _sessionId!,
        r'$process_person_profile': false,
      },
    };
    if (utf8.encode(jsonEncode(event)).length > 8192) return;
    _queue.add(event);
    if (_queue.length > _queueLimit) {
      _queue.removeRange(0, _queue.length - _queueLimit);
    }
  }

  String _uuidAt(DateTime now) =>
      const Uuid().v7(config: V7Options(now.millisecondsSinceEpoch, null));

  Future<void> flush() {
    final client = _client;
    if (client == null || _queue.isEmpty) return Future.value();
    final retryAt = _retryAt;
    if (retryAt != null && _now().isBefore(retryAt)) return Future.value();
    return _sending ??= _send(client, _generation);
  }

  Future<void> _send(http.Client client, int generation) async {
    try {
      while (generation == _generation && _queue.isNotEmpty) {
        final batch = _queue.take(_batchSize).toList();
        await _writes;
        if (generation != _generation) return;
        final abort = Completer<void>();
        final request =
            http.AbortableRequest('POST', _batchUrl, abortTrigger: abort.future)
              ..followRedirects = false
              ..headers['content-type'] = 'application/json'
              ..body = jsonEncode({
                'api_key': _token,
                'sent_at': _now().toUtc().toIso8601String(),
                'batch': batch,
              });
        final response = await client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                abort.complete();
                throw TimeoutException('PostHog upload timed out');
              },
            );
        if (generation != _generation) return;
        final status = response.statusCode;
        if (status != 200 && status != 400 && status != 413 && status != 422) {
          _backOff(response.headers['retry-after']);
          return;
        }
        // A rejected payload cannot succeed unchanged. Continue with the
        // remaining queue after removing only this batch.
        final sent = batch.map((event) => event['uuid']).toSet();
        _queue.removeWhere((event) => sent.contains(event['uuid']));
        _retryAt = null;
        _failures = 0;
        await _persist();
      }
    } catch (_) {
      if (generation == _generation) _backOff();
    } finally {
      if (generation == _generation) _sending = null;
    }
  }

  void _backOff([String? retryAfter]) {
    final interval = Duration(seconds: 60 << min(_failures++, 4));
    final requested = int.tryParse(retryAfter ?? '') ?? 0;
    _retryAt = _now().add(
      Duration(seconds: max(interval.inSeconds, requested.clamp(0, 86400))),
    );
  }

  void _restore() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null) return;
    try {
      final state = jsonDecode(raw);
      if (state is! Map ||
          state['token'] != _token ||
          state['url'] != _batchUrl.toString()) {
        return;
      }
      final id = state['id'];
      if (id is! String || id.isEmpty) return;
      _distinctId = id;
      final queue = state['queue'];
      if (queue is List) {
        _queue.addAll(
          queue
              .whereType<Map<String, dynamic>>()
              .where((event) {
                return event['distinct_id'] == id &&
                    event['uuid'] is String &&
                    event['event'] is String &&
                    event['timestamp'] is String &&
                    event['properties'] is Map;
              })
              .take(_queueLimit),
        );
      }
    } on FormatException {
      // A corrupt queue cannot be replayed.
    }
  }

  Future<void> _persist() {
    final id = _distinctId;
    final snapshot = id == null
        ? null
        : jsonEncode({
            'token': _token,
            'url': _batchUrl.toString(),
            'id': id,
            'queue': _queue,
          });
    final write = _writes.then((_) async {
      if (snapshot == null) {
        await clearStored(_preferences);
      } else if (!await _preferences.setString(_storageKey, snapshot)) {
        throw StateError('Could not save analytics queue');
      }
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
