import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadithsearcher/services/telemetry/replay_upload_queue.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('replay_queue_test_');
  });
  tearDown(() => directory.delete(recursive: true));

  ReplayUploadQueue open(
    String scope,
    Future<int?> Function(Uint8List) upload,
  ) => ReplayUploadQueue(
    path: path.join(directory.path, 'replay.db'),
    scope: scope,
    upload: upload,
    cancelUpload: () async {},
  );

  test(
    'retries the same requests in order after reopening the queue',
    () async {
      final first = Uint8List.fromList([1, 2, 3]);
      final second = Uint8List.fromList([4, 5]);
      final offline = open('project:identity', (_) async => null);
      try {
        expect(await offline.enqueue('session', first), isTrue);
        expect(await offline.enqueue('session', second), isTrue);
      } finally {
        await offline.close();
      }

      final requests = <Uint8List>[];
      final online = open('project:identity', (body) async {
        requests.add(body);
        return 200;
      });
      try {
        await online.flush();
        await online.flush();
        expect(requests, [first, second]);
      } finally {
        await online.close();
      }
    },
  );

  test(
    'keeps pending data scoped to the original project and identity',
    () async {
      final offline = open('project:old-identity', (_) async => null);
      try {
        expect(
          await offline.enqueue('session', Uint8List.fromList([1])),
          isTrue,
        );
      } finally {
        await offline.close();
      }

      final requests = <Uint8List>[];
      final online = open('project:new-identity', (body) async {
        requests.add(body);
        return 200;
      });
      try {
        final current = Uint8List.fromList([9]);
        expect(await online.enqueue('new-session', current), isTrue);
        await online.flush();
        expect(requests, [current]);
      } finally {
        await online.close();
      }
    },
  );
}
