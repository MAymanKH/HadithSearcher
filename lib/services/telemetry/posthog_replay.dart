import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/theme/app_palettes.g.dart';
import '../../models/settings.dart';

class PostHogReplay {
  final String token;
  final Uri host;
  final http.Client _client;

  static const _configLifetime = Duration(minutes: 5);
  static final _palette = AppPalettes.resolve(
    ColorSchemePreference.classic,
    Brightness.light,
  );
  DateTime? _configExpires;
  DateTime? _retryAfter;
  double? _sampleRate;
  String? _lastSession;
  String? _lastLayout;
  bool _sending = false;
  bool _closed = false;

  PostHogReplay(this.token, this.host, {http.Client? client})
    : _client = client ?? http.Client();

  void close() {
    _closed = true;
    _client.close();
  }

  Uri _endpoint(String path) =>
      host.replace(path: '${host.path.replaceFirst(RegExp(r'/+$'), '')}/$path');

  String _rgb(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

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
      _endpoint(
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

  Future<http.Response> _request(String method, Uri uri, [Object? body]) async {
    final request = http.Request(method, uri)..followRedirects = false;
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> capture({
    required DateTime now,
    required String distinctId,
    required String sessionId,
    required String screen,
    required Size size,
    required List<Rect> controls,
    Offset? tap,
  }) async {
    final retryAfter = _retryAfter;
    if (_closed ||
        _sending ||
        (retryAfter != null && now.isBefore(retryAfter))) {
      return;
    }
    if (controls.isEmpty) return;
    _sending = true;
    try {
      await _refreshConfig(now);
      final sample = _sampleRate;
      final bucket = int.parse(
        sessionId.substring(sessionId.length - 8),
        radix: 16,
      );
      if (_closed || sample == null || bucket / (1 << 32) >= sample) return;

      final width = size.width.round();
      final height = size.height.round();
      final wireframes = [
        {
          'id': 1,
          'type': 'rectangle',
          'x': 0,
          'y': 0,
          'width': width,
          'height': height,
          'style': {'backgroundColor': _rgb(_palette.surface)},
        },
        for (final (index, control) in controls.indexed)
          {
            'id': index + 2,
            'type': 'rectangle',
            'x': control.left.round(),
            'y': control.top.round(),
            'width': control.width.round(),
            'height': control.height.round(),
            'style': {
              'backgroundColor': _rgb(_palette.surfaceContainer),
              'borderColor': _rgb(_palette.outlineVariant),
              'borderWidth': 1,
              'borderRadius': 6,
            },
          },
      ];
      final layout = jsonEncode([screen, width, height, wireframes]);
      final newSession = _lastSession != sessionId;
      final newLayout = newSession || _lastLayout != layout;
      if (!newLayout && tap == null) return;
      final timestamp = now.millisecondsSinceEpoch;
      final response = await _request('POST', _endpoint('s/'), [
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
              if (newLayout) ...[
                {
                  'type': 4,
                  'timestamp': timestamp,
                  'data': {'href': screen, 'width': width, 'height': height},
                },
                {
                  'type': 2,
                  'timestamp': timestamp,
                  'data': {
                    'wireframes': wireframes,
                    'initialOffset': {'top': 0, 'left': 0},
                  },
                },
              ],
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastSession = sessionId;
        _lastLayout = layout;
      } else {
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
