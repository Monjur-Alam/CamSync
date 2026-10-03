import 'package:equatable/equatable.dart';

enum QueueStatus { queued, retrying, uploading, synced, failed }

QueueStatus queueStatusFromWire(String value) {
  return QueueStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => QueueStatus.queued,
  );
}

class QueuedImage extends Equatable {
  const QueuedImage({
    required this.clientImageId,
    required this.batchId,
    required this.filePath,
    required this.fileName,
    required this.bytes,
    required this.capturedAt,
    required this.status,
    required this.attempt,
    required this.progress,
    required this.createdAt,
    this.errorCode,
    this.remoteUrl,
    this.claimedAt = 0,
    this.nextAttemptAt = 0,
  });

  final String clientImageId;
  final String batchId;
  final String filePath;
  final String fileName;
  final int bytes;
  final String capturedAt;
  final QueueStatus status;
  final int attempt;
  final int progress;
  final int createdAt;
  final String? errorCode;
  final String? remoteUrl;
  final int claimedAt;
  final int nextAttemptAt;

  int get sortRank {
    switch (status) {
      case QueueStatus.uploading:
        return 0;
      case QueueStatus.retrying:
        return 1;
      case QueueStatus.queued:
        return 2;
      case QueueStatus.failed:
        return 3;
      case QueueStatus.synced:
        return 4;
    }
  }

  QueuedImage copyWith({
    QueueStatus? status,
    int? attempt,
    int? progress,
    String? errorCode,
    String? remoteUrl,
    int? claimedAt,
    int? nextAttemptAt,
    bool clearError = false,
  }) {
    return QueuedImage(
      clientImageId: clientImageId,
      batchId: batchId,
      filePath: filePath,
      fileName: fileName,
      bytes: bytes,
      capturedAt: capturedAt,
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      remoteUrl: remoteUrl ?? this.remoteUrl,
      claimedAt: claimedAt ?? this.claimedAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  factory QueuedImage.fromMap(Map<String, Object?> map) {
    return QueuedImage(
      clientImageId: map['client_image_id']! as String,
      batchId: map['batch_id']! as String,
      filePath: map['file_path']! as String,
      fileName: map['file_name']! as String,
      bytes: map['bytes']! as int,
      capturedAt: map['captured_at']! as String,
      status: queueStatusFromWire(map['status']! as String),
      attempt: map['attempt']! as int,
      progress: map['progress']! as int,
      createdAt: map['created_at']! as int,
      errorCode: map['error_code'] as String?,
      remoteUrl: map['remote_url'] as String?,
      claimedAt: (map['claimed_at'] as int?) ?? 0,
      nextAttemptAt: (map['next_attempt_at'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'client_image_id': clientImageId,
      'batch_id': batchId,
      'file_path': filePath,
      'file_name': fileName,
      'bytes': bytes,
      'captured_at': capturedAt,
      'status': status.name,
      'attempt': attempt,
      'progress': progress,
      'created_at': createdAt,
      'error_code': errorCode,
      'remote_url': remoteUrl,
      'claimed_at': claimedAt,
      'next_attempt_at': nextAttemptAt,
    };
  }

  @override
  List<Object?> get props => [
    clientImageId,
    batchId,
    filePath,
    fileName,
    bytes,
    capturedAt,
    status,
    attempt,
    progress,
    createdAt,
    errorCode,
    remoteUrl,
    claimedAt,
    nextAttemptAt,
  ];
}
