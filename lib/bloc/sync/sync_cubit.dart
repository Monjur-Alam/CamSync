import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/model/queued_image.dart';
import '../../data/repository/capture_repository.dart';
import '../../service/background_sync.dart';
import '../../service/sync_engine.dart';
import 'sync_state.dart';

class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required this.repository,
    required this.engine,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity(),
       super(const SyncState()) {
    _changes = repository.changes.listen((_) => reload());
    _link = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(refreshLink(pumpAfter: true));
    });
    unawaited(_start());
  }

  final CaptureRepository repository;
  final SyncEngine engine;
  final Connectivity _connectivity;

  StreamSubscription<void>? _changes;
  StreamSubscription<List<ConnectivityResult>>? _link;
  Timer? _timer;
  bool _busy = false;
  bool _again = false;
  bool _wasStable = false;

  Future<void> _start() async {
    final paused = await repository.isPaused();
    if (isClosed) return;
    emit(state.copyWith(paused: paused));
    await reload();
    await refreshLink(pumpAfter: true);
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (state.pendingCount == 0 && state.linkStable) return;
      unawaited(refreshLink(pumpAfter: true));
    });
  }

  Future<void> reload() async {
    final images = await repository.listAll();
    if (isClosed) return;
    emit(state.copyWith(images: _mergeProgress(images)));
  }

  List<QueuedImage> _mergeProgress(List<QueuedImage> incoming) {
    final live = {
      for (final image in state.images)
        if (image.status == QueueStatus.uploading) image.clientImageId: image,
    };
    return [
      for (final image in incoming)
        if (live[image.clientImageId] != null &&
            image.status == QueueStatus.uploading &&
            live[image.clientImageId]!.progress > image.progress)
          image.copyWith(progress: live[image.clientImageId]!.progress)
        else
          image,
    ];
  }

  Future<void> refreshLink({bool pumpAfter = false}) async {
    final results = await _connectivity.checkConnectivity();
    final online = results.any((result) => result != ConnectivityResult.none);
    var stable = false;
    if (online) stable = await engine.client.health();
    if (isClosed) return;
    final becameStable = stable && !_wasStable;
    _wasStable = stable;
    emit(state.copyWith(online: online, linkStable: stable));
    if (becameStable) unawaited(kickBackgroundSync());
    if (pumpAfter && stable && !state.paused) await pump();
  }

  Future<void> pump() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await engine.drain(
          onClaimed: (image) => _replace(image),
          onProgress: (id, progress) => _replaceProgress(id, progress),
        );
        await reload();
      } while (_again && !await repository.isPaused() && !isClosed);
    } finally {
      _busy = false;
    }
  }

  Future<void> togglePause() async {
    final next = !state.paused;
    await repository.setPaused(next);
    if (next) engine.stop();
    if (isClosed) return;
    emit(state.copyWith(paused: next));
    if (!next) unawaited(pump());
  }

  Future<void> startNewBatch() => repository.startNewBatch();

  void _replace(QueuedImage image) {
    final images = [
      for (final current in state.images)
        if (current.clientImageId == image.clientImageId) image else current,
    ];
    if (!images.any((item) => item.clientImageId == image.clientImageId)) {
      images.insert(0, image);
    }
    images.sort((a, b) {
      final rank = a.sortRank.compareTo(b.sortRank);
      if (rank != 0) return rank;
      return b.createdAt.compareTo(a.createdAt);
    });
    emit(state.copyWith(images: images));
  }

  void _replaceProgress(String id, int progress) {
    for (final image in state.images) {
      if (image.clientImageId != id) continue;
      _replace(
        image.copyWith(status: QueueStatus.uploading, progress: progress),
      );
      return;
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _changes?.cancel();
    await _link?.cancel();
    engine.stop();
    return super.close();
  }
}
