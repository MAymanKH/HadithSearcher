import 'dart:async';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

class ReplayUploadQueue {
  static const _byteLimit = 32 * 1024 * 1024;
  static const _requestLimit = 1024;
  static const _retention = Duration(hours: 24);
  static const _interval = Duration(seconds: 15);

  final Future<int?> Function(Uint8List) _upload;
  final Future<void> Function() _cancelUpload;
  final String _scope;
  final Future<Database> _database;
  Future<void>? _flushing;
  Timer? _retry;
  bool _enqueued = false;
  bool _closed = false;

  ReplayUploadQueue({
    required String path,
    required String scope,
    required this._upload,
    required this._cancelUpload,
  }) : _scope = scope,
       _database = _open(path, scope) {
    unawaited(flush());
  }

  static Future<Database> _open(String path, String scope) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE uploads (
          id INTEGER PRIMARY KEY,
          scope TEXT NOT NULL,
          session TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          body BLOB NOT NULL
        )
      '''),
    );
    try {
      await db.delete('uploads', where: 'scope != ?', whereArgs: [scope]);
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<bool> enqueue(String session, Uint8List body) async {
    if (_closed || body.length > _byteLimit) return false;
    final db = await _database;
    if (_closed) return false;
    final saved = await db.transaction((tx) async {
      if (_closed) return false;
      final used = (await tx.rawQuery('''
        SELECT count(*) AS requests, coalesce(sum(length(body)), 0) AS bytes
        FROM uploads
      ''')).single;
      if ((used['requests'] as int) >= _requestLimit ||
          (used['bytes'] as int) + body.length > _byteLimit) {
        return false;
      }
      await tx.insert('uploads', {
        'scope': _scope,
        'session': session,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'body': body,
      });
      return true;
    });
    if (saved) {
      _enqueued = true;
      unawaited(flush());
    }
    return saved;
  }

  Future<void> flush() {
    if (_closed || _retry != null) return Future.value();
    return _flushing ??= _drain();
  }

  Future<void> _drain() async {
    try {
      final db = await _database;
      if (_closed) return;
      final cutoff = DateTime.now().subtract(_retention).millisecondsSinceEpoch;
      await db.rawDelete(
        '''
        DELETE FROM uploads WHERE session IN (
          SELECT session FROM uploads WHERE created_at < ?
        )
      ''',
        [cutoff],
      );
      while (!_closed) {
        _enqueued = false;
        final rows = await db.query(
          'uploads',
          columns: ['id', 'body'],
          orderBy: 'id',
          limit: 1,
        );
        if (_closed) return;
        if (rows.isEmpty) {
          if (_enqueued) continue;
          return;
        }
        final row = rows.single;
        final status = await _upload(row['body'] as Uint8List);
        if (_closed) return;
        final accepted = status != null && status >= 200 && status < 300;
        if (!accepted && status != 400 && status != 413 && status != 422) {
          _retryLater();
          return;
        }
        await db.delete('uploads', where: 'id = ?', whereArgs: [row['id']]);
      }
    } catch (_) {
      _retryLater();
    } finally {
      _flushing = null;
    }
  }

  void _retryLater() {
    if (_closed) return;
    _retry = Timer(_interval, () {
      _retry = null;
      unawaited(flush());
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retry?.cancel();
    try {
      await _cancelUpload();
    } finally {
      await _flushing;
      final db = await _database;
      await db.close();
    }
  }
}
