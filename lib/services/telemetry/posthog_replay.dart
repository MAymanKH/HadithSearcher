import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'replay_upload_queue.dart';
import 'telemetry_service.dart';

typedef EncodeReplayWebp = Future<Uint8List?> Function(Uint8List png);

class PostHogReplay {
  final String token;
  final Uri host;
  final http.Client _client;
  final EncodeReplayWebp? _encodeWebp;
  final ReplayUploadQueue? _wifiQueue;
  Completer<void>? _activeAbort;

  static const _configLifetime = Duration(minutes: 5);
  DateTime? _configExpires;
  DateTime? _retryAfter;
  double? _sampleRate;
  String? _lastSession;
  String? _lastScreen;
  Size? _lastSize;
  Uint8List? _lastPng;
  bool _sending = false;
  bool _closed = false;

  PostHogReplay(
    this.token,
    this.host, {
    http.Client? client,
    this._encodeWebp,
    this._wifiQueue,
  }) : _client = client ?? http.Client();

  Future<void> close() async {
    _closed = true;
    _lastPng = null;
    _abortRequest();
    _client.close();
    await _wifiQueue?.close();
  }

  void flushQueued() => _wifiQueue?.flush();

  void _abortRequest() {
    _activeAbort?.complete();
    _activeAbort = null;
  }

  static Uri endpoint(Uri host, String path) =>
      host.replace(path: '${host.path.replaceFirst(RegExp(r'/+$'), '')}/$path');

  Future<void> _refreshConfig(DateTime now) async {
    final expires = _configExpires;
    if (expires != null && now.isBefore(expires)) return;
    _sampleRate = null;
    _configExpires = now.add(_configLifetime);
    final assetsHost = switch (host.host) {
      'eu.i.posthog.com' => 'eu-assets.i.posthog.com',
      'us.i.posthog.com' => 'us-assets.i.posthog.com',
      _ => host.host,
    };
    final response = await _request(
      'GET',
      endpoint(
        host,
        'array/${Uri.encodeComponent(token)}/config',
      ).replace(host: assetsHost),
    );
    if (response.statusCode != 200) return;
    final config = jsonDecode(response.body);
    if (config is! Map) return;
    final quota = config['quotaLimited'];
    if (quota is List && quota.contains('mobile_recordings')) return;
    final recording = config['sessionRecording'];
    if (recording == true) {
      _sampleRate = 1;
      return;
    }
    if (recording is! Map ||
        recording['linkedFlag'] != null ||
        _hasRules(recording['urlTriggers']) ||
        _hasRules(recording['urlBlocklist']) ||
        _hasRules(recording['eventTriggers']) ||
        (recording['minimumDurationMilliseconds'] != null &&
            recording['minimumDurationMilliseconds'] != 0)) {
      return;
    }
    final rate = recording['sampleRate'];
    final sample = rate == null ? 1.0 : double.tryParse(rate.toString());
    if (sample != null && sample.isFinite && sample >= 0 && sample <= 1) {
      _sampleRate = sample;
    }
  }

  bool _hasRules(Object? rules) =>
      rules != null && (rules is! List || rules.isNotEmpty);

  Future<http.Response> _request(
    String method,
    Uri uri, [
    Uint8List? body,
  ]) async {
    final abort = _activeAbort = Completer<void>();
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    )..followRedirects = false;
    if (body != null) {
      request.headers
        ..['content-type'] = 'application/json'
        ..['content-encoding'] = 'gzip';
      request.bodyBytes = body;
    }
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _abortRequest();
              throw TimeoutException('PostHog replay request timed out');
            },
          );
    } finally {
      _activeAbort = null;
    }
  }

  Future<String> _imageData(Uint8List png) async {
    Uint8List? webp;
    try {
      webp = await _encodeWebp?.call(png);
    } catch (_) {
      // The captured PNG is available if the platform encoder fails.
    }
    if (webp != null && webp.isNotEmpty && webp.length < png.length) {
      return 'data:image/webp;base64,${base64Encode(webp)}';
    }
    return 'data:image/png;base64,${base64Encode(png)}';
  }

  Future<void> capture({
    required DateTime now,
    required String distinctId,
    required String sessionId,
    required String screen,
    required CaptureReplayFrame captureFrame,
    Offset? tap,
  }) async {
    final retryAfter = _retryAfter;
    if (_closed ||
        _sending ||
        (retryAfter != null && now.isBefore(retryAfter))) {
      return;
    }
    _sending = true;
    try {
      await _refreshConfig(now);
      final sample = _sampleRate;
      final bucket = int.parse(
        sessionId.substring(sessionId.length - 8),
        radix: 16,
      );
      if (_closed || sample == null || bucket / (1 << 32) >= sample) return;

      final frame = await captureFrame();
      if (_closed || frame == null) return;

      final width = frame.size.width.round();
      final height = frame.size.height.round();
      final newViewport =
          _lastSession != sessionId ||
          _lastScreen != screen ||
          _lastSize != frame.size;
      final newImage = newViewport || !listEquals(_lastPng, frame.png);
      if (!newImage && tap == null) return;
      final imageData = newImage ? await _imageData(frame.png) : null;
      if (_closed) return;
      final timestamp = now.millisecondsSinceEpoch;
      final body = await compute(_gzipReplay, [
        {
          'api_key': token,
          'event': r'$snapshot',
          'uuid': const Uuid().v7(),
          'distinct_id': distinctId,
          'timestamp': now.toUtc().toIso8601String(),
          'properties': {
            r'$session_id': sessionId,
            r'$window_id': sessionId,
            r'$snapshot_source': 'mobile',
            r'$process_person_profile': false,
            r'$snapshot_data': [
              if (newViewport)
                {
                  'type': 4,
                  'timestamp': timestamp,
                  'data': {'href': screen, 'width': width, 'height': height},
                },
              if (imageData != null)
                {
                  'type': 2,
                  'timestamp': timestamp,
                  'data': {
                    'wireframes': [
                      {
                        'id': 1,
                        'type': 'screenshot',
                        'x': 0,
                        'y': 0,
                        'width': width,
                        'height': height,
                        'base64': imageData,
                      },
                    ],
                    'initialOffset': {'top': 0, 'left': 0},
                  },
                },
              if (tap != null)
                {
                  'type': 3,
                  'timestamp': timestamp,
                  'data': {
                    'id': 1,
                    'source': 2,
                    'type': 2,
                    'pointerType': 2,
                    'x': tap.dx.round(),
                    'y': tap.dy.round(),
                  },
                },
            ],
          },
        },
      ]);
      if (_closed) return;
      final queue = _wifiQueue;
      final bool accepted;
      if (queue == null) {
        final response = await _request('POST', endpoint(host, 's/'), body);
        accepted = response.statusCode >= 200 && response.statusCode < 300;
      } else {
        accepted = await queue.enqueue(sessionId, body);
      }
      if (_closed) return;
      if (accepted) {
        _lastSession = sessionId;
        _lastScreen = screen;
        _lastSize = frame.size;
        _lastPng = frame.png;
      } else if (queue == null) {
        _retryAfter = now.add(const Duration(seconds: 30));
      }
    } catch (_) {
      // Replay failures must never interrupt the UI.
      _retryAfter = now.add(const Duration(seconds: 30));
    } finally {
      _sending = false;
    }
  }
}

Uint8List _gzipReplay(List<Map<String, Object>> body) =>
    Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(body))));
