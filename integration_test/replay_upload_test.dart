import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/services/telemetry/sdk_telemetry_backend.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _verifyReconnect = bool.fromEnvironment('VERIFY_REPLAY_WIFI_RECONNECT');
const _nativeReplay = MethodChannel('hadithsearcher/replay');
const _nativeEncoder = MethodChannel('hadithsearcher/replay_encoder');
typedef _Frame = ({Size size, Uint8List png});
typedef _Upload = ({String? encoding, List<int> bytes});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('measure real replay uploads and compare decoded pixels', (
    tester,
  ) async {
    final receiver = await _Receiver.start();
    addTearDown(receiver.close);
    final boundary = await _openApp(tester, receiver);
    final frames = <_Frame>[];
    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await tester.pumpAndSettle();
      frames.add(await _capture(boundary));
    }

    final png = await _sendFrames(receiver, frames, webp: false);
    final webp = await _sendFrames(receiver, frames, webp: true);
    var originalBytes = 0;
    var gzipBytes = 0;
    var webpBytes = 0;
    for (var index = 0; index < frames.length; index++) {
      final pngRequest = png[index];
      final webpRequest = webp[index];
      final pngData = _image(pngRequest);
      final webpData = _image(webpRequest);
      final encoded = await _nativeEncoder.invokeMethod<Uint8List>(
        'encodeWebp',
        frames[index].png,
      );
      expect(encoded, isNotNull);
      expect(pngData.mimeType, 'image/png');
      expect(
        webpData.mimeType,
        encoded!.length < frames[index].png.length ? 'image/webp' : 'image/png',
      );
      debugPrint(
        'REPLAY_FRAME_BYTES frame=$index png=${frames[index].png.length} '
        'webp=${encoded.length} sent=${webpData.mimeType}',
      );
      expect(pngData.contentAsBytes(), frames[index].png);
      final original = await _pixels(pngData.contentAsBytes());
      final restored = await _pixels(webpData.contentAsBytes());
      expect(restored.width, original.width);
      expect(restored.height, original.height);
      expect(restored.bytes, original.bytes);
      originalBytes += gzip.decode(pngRequest.bytes).length;
      gzipBytes += pngRequest.bytes.length;
      webpBytes += webpRequest.bytes.length;
    }
    expect(gzipBytes, lessThan(originalBytes));
    expect(webpBytes, lessThan(gzipBytes));
    debugPrint(
      'REPLAY_UPLOAD_BYTES frames=${frames.length} plain_png=$originalBytes '
      'gzip_png=$gzipBytes gzip_webp=$webpBytes',
    );
  }, skip: _verifyReconnect);

  testWidgets('queue replay off Wi-Fi and deliver it after reconnect', (
    tester,
  ) async {
    final receiver = await _Receiver.start();
    addTearDown(receiver.close);
    final boundary = await _openApp(tester, receiver);
    final frame = await _capture(boundary);
    final backend = receiver.backend(wifiOnly: true);
    addTearDown(() => backend.setAnalyticsEnabled(false));
    await backend.setAnalyticsEnabled(true);
    await backend.capture('screen_viewed', {'screen': 'wifi_verification'});
    await backend.captureReplay(() async => frame, const Offset(24, 42));
    final queuePath = (await _nativeReplay.invokeMethod<String>('queuePath'))!;
    expect(await File(queuePath).exists(), isTrue);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(receiver.uploads, isEmpty);
    debugPrint('REPLAY_WAITING_FOR_WIFI');

    final request = await receiver.nextUpload.future.timeout(
      const Duration(seconds: 40),
    );
    expect(_image(request).contentAsBytes(), frame.png);
    await backend.setAnalyticsEnabled(false);
    expect(await File(queuePath).exists(), isFalse);
  }, skip: !_verifyReconnect);
}

Future<RenderRepaintBoundary> _openApp(
  WidgetTester tester,
  _Receiver receiver,
) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.clear();
  await preferences.setBool('welcomeCompleted', true);
  await preferences.setString(
    TelemetryService.consentKey,
    const TelemetryConsent(decided: true).encode(),
  );
  final telemetry = TelemetryService(
    preferences: preferences,
    backend: receiver.backend(),
  );
  addTearDown(telemetry.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: HadithSearcherApp(
        initialThemeMode: ThemeMode.light,
        telemetry: telemetry,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
}

Future<_Frame> _capture(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage();
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return (size: boundary.size, png: Uint8List.sublistView(bytes));
  } finally {
    image.dispose();
  }
}

Future<List<_Upload>> _sendFrames(
  _Receiver receiver,
  List<_Frame> frames, {
  required bool webp,
}) async {
  final backend = receiver.backend(webp: webp);
  final start = receiver.uploads.length;
  await backend.setAnalyticsEnabled(true);
  try {
    for (final (index, frame) in frames.indexed) {
      await backend.capture('screen_viewed', {'screen': 'benchmark_$index'});
      await backend.captureReplay(() async => frame, const Offset(24, 42));
    }
    final uploads = receiver.uploads.sublist(start);
    expect(uploads, hasLength(frames.length));
    return uploads;
  } finally {
    await backend.setAnalyticsEnabled(false);
  }
}

UriData _image(_Upload upload) {
  expect(upload.encoding, 'gzip');
  final payload = jsonDecode(utf8.decode(gzip.decode(upload.bytes))) as List;
  final snapshot = payload.single;
  expect(snapshot['event'], r'$snapshot');
  final frames = snapshot['properties'][r'$snapshot_data'] as List;
  final tap = frames.singleWhere((event) => event['type'] == 3)['data'];
  expect(tap['x'], 24);
  expect(tap['y'], 42);
  final frame = frames.singleWhere((event) => event['type'] == 2)['data'];
  return UriData.parse(
    (frame['wireframes'] as List).single['base64'] as String,
  );
}

Future<({int width, int height, Uint8List bytes})> _pixels(
  Uint8List data,
) async {
  final codec = await ui.instantiateImageCodec(data);
  final frame = await codec.getNextFrame();
  try {
    final image = frame.image;
    final bytes = (await image.toByteData())!;
    return (
      width: image.width,
      height: image.height,
      bytes: Uint8List.sublistView(bytes),
    );
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}

class _Receiver {
  final HttpServer _server;
  final uploads = <_Upload>[];
  final nextUpload = Completer<_Upload>();

  _Receiver(this._server);

  static Future<_Receiver> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final receiver = _Receiver(server);
    server.listen(receiver._receive);
    return receiver;
  }

  Future<void> _receive(HttpRequest request) async {
    final bytes = await request.fold(
      <int>[],
      (body, part) => body..addAll(part),
    );
    request.response.headers.contentType = ContentType.json;
    if (request.uri.path.endsWith('/config')) {
      request.response.write('{"sessionRecording":{"sampleRate":"1"}}');
    } else if (request.uri.path == '/s/') {
      final upload = (
        encoding: request.headers.value('content-encoding'),
        bytes: bytes,
      );
      uploads.add(upload);
      if (!nextUpload.isCompleted) nextUpload.complete(upload);
    }
    await request.response.close();
  }

  SdkTelemetryBackend backend({bool webp = false, bool wifiOnly = false}) =>
      SdkTelemetryBackend(
        posthogToken: 'phc_replay_test',
        posthogHost: 'http://127.0.0.1:${_server.port}',
        replayWebp: webp,
        replayWifiOnly: wifiOnly,
      );

  Future<void> close() => _server.close(force: true);
}
