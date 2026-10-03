import 'package:equatable/equatable.dart';

import '../../data/model/queued_image.dart';

class SyncState extends Equatable {
  const SyncState({
    this.online = false,
    this.linkStable = false,
    this.paused = false,
    this.images = const [],
  });

  final bool online;
  final bool linkStable;
  final bool paused;
  final List<QueuedImage> images;

  int get pendingCount =>
      images.where((image) => image.status != QueueStatus.synced).length;

  int get totalBytes => images.fold(0, (sum, image) => sum + image.bytes);

  int get uploadedBytes {
    var done = 0;
    for (final image in images) {
      if (image.status == QueueStatus.synced) {
        done += image.bytes;
      } else if (image.status == QueueStatus.uploading) {
        done += (image.bytes * image.progress / 100).round();
      }
    }
    return done;
  }

  double get fraction {
    if (totalBytes <= 0) return 0;
    return (uploadedBytes / totalBytes).clamp(0, 1);
  }

  SyncState copyWith({
    bool? online,
    bool? linkStable,
    bool? paused,
    List<QueuedImage>? images,
  }) {
    return SyncState(
      online: online ?? this.online,
      linkStable: linkStable ?? this.linkStable,
      paused: paused ?? this.paused,
      images: images ?? this.images,
    );
  }

  @override
  List<Object?> get props => [online, linkStable, paused, images];
}
