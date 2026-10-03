import 'package:cam_sync/bloc/sync/sync_state.dart';
import 'package:cam_sync/data/model/queued_image.dart';
import 'package:cam_sync/ui/upload/upload_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('upload manager shows the queue chrome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UploadDashboard(
          state: SyncState(
            online: true,
            linkStable: true,
            images: [
              QueuedImage(
                clientImageId: 'img_1',
                batchId: 'batch_1',
                filePath: 'missing.jpg',
                fileName: 'CAPTURE_20261002_120000.jpg',
                bytes: 2 * 1024 * 1024,
                capturedAt: '2026-10-02T12:00:00.000Z',
                status: QueueStatus.queued,
                attempt: 0,
                progress: 0,
                createdAt: 1,
              ),
            ],
          ),
          onPause: () {},
          onNewBatch: () {},
        ),
      ),
    );

    expect(find.text('Upload Manager'), findsOneWidget);
    expect(find.text('STABLE LINK'), findsOneWidget);
    expect(find.text('PAUSE ALL'), findsOneWidget);
    expect(find.text('PENDING UPLOADS (1)'), findsOneWidget);
    expect(find.text('IN QUEUE'), findsOneWidget);
    expect(find.text('START NEW UPLOAD BATCH'), findsOneWidget);
    expect(find.text('CAPTURE_20261002_120000.jpg'), findsOneWidget);
  });
}
