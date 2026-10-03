import '../../data/model/queued_image.dart';

/// Status line printed on an upload card.
String statusLabel(QueuedImage image, {required bool online}) {
  switch (image.status) {
    case QueueStatus.synced:
      return 'SYNCED';
    case QueueStatus.failed:
      return 'FAILED';
    case QueueStatus.uploading:
      return 'UPLOADING - ${image.progress}%';
    case QueueStatus.retrying:
      if (!online) return 'WAITING FOR CONNECTION';
      final attempt = image.attempt.clamp(1, 5);
      return 'RETRYING... (ATTEMPT $attempt/5)';
    case QueueStatus.queued:
      if (!online) return 'WAITING FOR CONNECTION';
      return 'IN QUEUE';
  }
}

ColorRole statusRole(QueuedImage image, {required bool online}) {
  switch (image.status) {
    case QueueStatus.synced:
      return ColorRole.synced;
    case QueueStatus.failed:
      return ColorRole.failed;
    case QueueStatus.uploading:
      return ColorRole.uploading;
    case QueueStatus.retrying:
      return online ? ColorRole.retrying : ColorRole.waiting;
    case QueueStatus.queued:
      return online ? ColorRole.queued : ColorRole.waiting;
  }
}

enum ColorRole { synced, failed, uploading, retrying, waiting, queued }
