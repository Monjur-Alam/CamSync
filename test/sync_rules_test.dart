import 'package:cam_sync/core/util/byte_format.dart';
import 'package:cam_sync/core/util/status_label.dart';
import 'package:cam_sync/data/api/upload_result.dart';
import 'package:cam_sync/data/model/queued_image.dart';
import 'package:flutter_test/flutter_test.dart';

QueuedImage _image({
  QueueStatus status = QueueStatus.queued,
  int attempt = 0,
  int progress = 0,
}) {
  return QueuedImage(
    clientImageId: 'img_test',
    batchId: 'batch_test',
    filePath: '/tmp/CAPTURE_1.jpg',
    fileName: 'CAPTURE_1.jpg',
    bytes: 88 * 1024 * 1024,
    capturedAt: '2026-10-02T12:00:00.000Z',
    status: status,
    attempt: attempt,
    progress: progress,
    createdAt: 1,
  );
}

void main() {
  test('formats sizes the way the upload cards print them', () {
    expect(formatBytes(0), '0 MB');
    expect(formatBytes(88 * 1024 * 1024), '88 MB');
    expect(formatBytes((2.1 * 1024 * 1024).round()), '2.1 MB');
    expect(formatBytes((1.2 * 1024 * 1024 * 1024).round()), '1.2 GB');
  });

  test('keeps a capture queued until the link answers', () {
    expect(statusLabel(_image(), online: false), 'WAITING FOR CONNECTION');
    expect(statusLabel(_image(), online: true), 'IN QUEUE');
    expect(
      statusLabel(
        _image(status: QueueStatus.retrying, attempt: 3),
        online: true,
      ),
      'RETRYING... (ATTEMPT 3/5)',
    );
    expect(
      statusLabel(
        _image(status: QueueStatus.uploading, progress: 65),
        online: true,
      ),
      'UPLOADING - 65%',
    );
    expect(
      statusLabel(_image(status: QueueStatus.synced), online: true),
      'SYNCED',
    );
  });

  test('treats 201 and duplicate 200 as done, and keeps retryable failures', () {
    expect(
      interpretUpload(
        status: 201,
        body: const {'ok': true, 'duplicate': false},
        transportError: false,
      ).disposition,
      UploadDisposition.synced,
    );
    expect(
      interpretUpload(
        status: 200,
        body: const {'ok': true, 'duplicate': true},
        transportError: false,
      ).disposition,
      UploadDisposition.synced,
    );
    expect(
      interpretUpload(
        status: 400,
        body: const {
          'retryable': true,
          'error': {'code': 'partial_upload'},
        },
        transportError: false,
      ).disposition,
      UploadDisposition.retry,
    );
    expect(
      interpretUpload(
        status: 401,
        body: const {
          'retryable': false,
          'error': {'code': 'unauthorized'},
        },
        transportError: false,
      ).disposition,
      UploadDisposition.stop,
    );
    expect(
      interpretUpload(
        status: 415,
        body: const {
          'error': {'code': 'unsupported_type'},
        },
        transportError: false,
      ).disposition,
      UploadDisposition.stop,
    );
    expect(
      interpretUpload(
        status: null,
        body: null,
        transportError: true,
      ).disposition,
      UploadDisposition.retry,
    );
    expect(
      interpretUpload(
        status: 503,
        body: const {'ok': false},
        transportError: false,
      ).disposition,
      UploadDisposition.retry,
    );
  });
}
