import 'dart:io';

import 'package:dio/dio.dart';

import '../data/api/camsync_client.dart';
import '../data/api/upload_result.dart';
import '../data/model/queued_image.dart';
import '../data/repository/capture_repository.dart';

typedef ClaimListener = void Function(QueuedImage image);
typedef ProgressListener = void Function(String id, int progress);

/// Uploads one queued capture at a time and leaves failures in the local queue.
class SyncEngine {
  SyncEngine({required this.repository, required this.client});

  final CaptureRepository repository;
  final CamSyncClient client;

  CancelToken? _token;
  bool _stopped = false;
  int _lastProgress = -1;

  void stop() {
    _stopped = true;
    _token?.cancel('paused');
  }

  Future<void> drain({
    ClaimListener? onClaimed,
    ProgressListener? onProgress,
  }) async {
    _stopped = false;
    _token = CancelToken();
    await repository.recoverStaleClaims();
    await _reconcile();
    if (_stopped || await repository.isPaused()) return;
    if (!await client.health()) return;

    while (!_stopped && !await repository.isPaused()) {
      final next = await repository.claimNext();
      if (next == null || _stopped) return;
      onClaimed?.call(next);
      _lastProgress = -1;

      if (!await File(next.filePath).exists()) {
        await repository.markFailed(next.clientImageId, 'missing_file');
        continue;
      }

      final result = await client.upload(
        next,
        deviceId: await repository.deviceId(),
        cancelToken: _token,
        onProgress: (progress) {
          if ((progress - _lastProgress).abs() < 2 && progress != 100) return;
          _lastProgress = progress;
          onProgress?.call(next.clientImageId, progress);
          repository.setProgress(next.clientImageId, progress);
        },
      );

      if (_stopped || result.disposition == UploadDisposition.cancelled) {
        await repository.releaseClaim(next.clientImageId);
        return;
      }
      if (result.synced) {
        await repository.markSynced(
          next.clientImageId,
          remoteUrl: result.remoteUrl,
        );
        continue;
      }
      if (result.disposition == UploadDisposition.stop) {
        await repository.markFailed(
          next.clientImageId,
          result.errorCode ?? 'rejected',
        );
        continue;
      }
      await repository.markRetry(next, errorCode: result.errorCode);
    }
  }

  Future<void> _reconcile() async {
    try {
      final batches = await repository.batchIdsWithPending();
      for (final batchId in batches) {
        if (_stopped) return;
        final ids = await client.storedIds(batchId);
        await repository.markSyncedFromServer(ids);
      }
    } catch (_) {
      // A reconcile failure must not clear the queue.
    }
  }
}
