import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/util/ids.dart';
import '../db/sync_database.dart';
import '../image_compress.dart';
import '../model/queued_image.dart';

class BatchBadge {
  const BatchBadge({required this.pending, this.thumbPath});

  final int pending;
  final String? thumbPath;
}

class CaptureRepository {
  CaptureRepository(this._database);

  final SyncDatabase _database;
  final _changes = StreamController<void>.broadcast();

  Database get _db => _database.raw;
  Stream<void> get changes => _changes.stream;

  Future<void> ensureDeviceAndBatch() async {
    if (await _meta('device_id') == null) {
      await _setMeta('device_id', newDeviceId());
    }
    if (await _meta('active_batch') == null) {
      await _setMeta('active_batch', newBatchId());
    }
    if (await _meta('sync_paused') == null) {
      await _setMeta('sync_paused', '0');
    }
  }

  Future<String> deviceId() async => (await _meta('device_id'))!;

  Future<String> activeBatchId() async => (await _meta('active_batch'))!;

  Future<bool> isPaused() async => (await _meta('sync_paused')) == '1';

  Future<void> setPaused(bool paused) async {
    await _setMeta('sync_paused', paused ? '1' : '0');
    _ping();
  }

  Future<String> startNewBatch() async {
    final id = newBatchId();
    await _setMeta('active_batch', id);
    _ping();
    return id;
  }

  Future<QueuedImage> saveCapture(String sourcePath) async {
    final captured = DateTime.now().toUtc();
    final batchId = await activeBatchId();
    final imageId = newImageId();
    var fileName = captureFileName(captured.toLocal());
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docs.path, 'captures'));
    await folder.create(recursive: true);
    if (await File(p.join(folder.path, fileName)).exists()) {
      fileName = fileName.replaceFirst('.jpg', '_$imageId.jpg');
    }
    final saved = await writeCaptureFile(
      source: File(sourcePath),
      destinationPath: p.join(folder.path, fileName),
    );
    final source = File(sourcePath);
    if (source.path != saved.path && await source.exists()) {
      await source.delete();
    }
    final image = QueuedImage(
      clientImageId: imageId,
      batchId: batchId,
      filePath: saved.path,
      fileName: fileName,
      bytes: await saved.length(),
      capturedAt: captured.toIso8601String(),
      status: QueueStatus.queued,
      attempt: 0,
      progress: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.insert('images', image.toMap());
    _ping();
    return image;
  }

  Future<BatchBadge> activeBatchBadge() async {
    final batchId = await activeBatchId();
    final pending = Sqflite.firstIntValue(
      await _db.rawQuery(
        "SELECT COUNT(*) FROM images WHERE batch_id = ? AND status != 'synced'",
        [batchId],
      ),
    );
    final latest = await _db.query(
      'images',
      columns: ['file_path'],
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return BatchBadge(
      pending: pending ?? 0,
      thumbPath: latest.isEmpty ? null : latest.first['file_path'] as String?,
    );
  }

  Future<List<QueuedImage>> listAll() async {
    final rows = await _db.query('images');
    final images = rows.map(QueuedImage.fromMap).toList();
    images.sort((a, b) {
      final rank = a.sortRank.compareTo(b.sortRank);
      if (rank != 0) return rank;
      return b.createdAt.compareTo(a.createdAt);
    });
    return images;
  }

  Future<List<String>> batchIdsWithPending() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT batch_id FROM images WHERE status != 'synced'",
    );
    return [for (final row in rows) row['batch_id']! as String];
  }

  Future<void> markSyncedFromServer(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final batch = _db.batch();
    for (final id in list) {
      batch.update(
        'images',
        {'status': QueueStatus.synced.name, 'progress': 100},
        where: 'client_image_id = ? AND status != ?',
        whereArgs: [id, QueueStatus.synced.name],
      );
    }
    await batch.commit(noResult: true);
    _ping();
  }

  Future<void> recoverStaleClaims() async {
    final cutoff = DateTime.now().millisecondsSinceEpoch -
        const Duration(minutes: 3).inMilliseconds;
    final changed = await _db.update(
      'images',
      {'status': QueueStatus.queued.name, 'progress': 0},
      where: "status = 'uploading' AND claimed_at <= ?",
      whereArgs: [cutoff],
    );
    if (changed > 0) _ping();
  }

  Future<QueuedImage?> claimNext() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'images',
        where: "status IN ('queued', 'retrying') AND next_attempt_at <= ?",
        whereArgs: [now],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final current = QueuedImage.fromMap(rows.first);
      final updated = await txn.update(
        'images',
        {
          'status': QueueStatus.uploading.name,
          'progress': 0,
          'claimed_at': now,
        },
        where: 'client_image_id = ? AND status IN (?, ?)',
        whereArgs: [
          current.clientImageId,
          QueueStatus.queued.name,
          QueueStatus.retrying.name,
        ],
      );
      if (updated == 0) return null;
      return current.copyWith(
        status: QueueStatus.uploading,
        progress: 0,
        claimedAt: now,
      );
    });
  }

  Future<void> setProgress(String id, int progress) async {
    await _db.update(
      'images',
      {'progress': progress.clamp(0, 100)},
      where: 'client_image_id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(String id, {String? remoteUrl}) async {
    await _db.update(
      'images',
      {
        'status': QueueStatus.synced.name,
        'progress': 100,
        'remote_url': remoteUrl,
        'error_code': null,
      },
      where: 'client_image_id = ?',
      whereArgs: [id],
    );
    _ping();
  }

  Future<void> markRetry(QueuedImage image, {String? errorCode}) async {
    final attempt = image.attempt + 1;
    final delaySeconds = (1 << attempt).clamp(2, 60).toInt();
    await _db.update(
      'images',
      {
        'status': QueueStatus.retrying.name,
        'attempt': attempt,
        'progress': 0,
        'error_code': errorCode,
        'next_attempt_at':
            DateTime.now().millisecondsSinceEpoch + delaySeconds * 1000,
      },
      where: 'client_image_id = ?',
      whereArgs: [image.clientImageId],
    );
    _ping();
  }

  Future<void> markFailed(String id, String errorCode) async {
    await _db.update(
      'images',
      {
        'status': QueueStatus.failed.name,
        'progress': 0,
        'error_code': errorCode,
      },
      where: 'client_image_id = ?',
      whereArgs: [id],
    );
    _ping();
  }

  Future<void> releaseClaim(String id) async {
    await _db.update(
      'images',
      {'status': QueueStatus.queued.name, 'progress': 0},
      where: 'client_image_id = ? AND status = ?',
      whereArgs: [id, QueueStatus.uploading.name],
    );
    _ping();
  }

  Future<String?> _meta(String key) async {
    final rows = await _db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _setMeta(String key, String value) async {
    await _db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _ping() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
