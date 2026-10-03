import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/repository/capture_repository.dart';
import 'camera_state.dart';

class CameraCubit extends Cubit<CameraState> {
  CameraCubit({required this.repository, this.onCaptured})
    : super(const CameraState()) {
    _changes = repository.changes.listen((_) => refreshBadge());
    unawaited(start());
  }

  final CaptureRepository repository;
  final VoidCallback? onCaptured;

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  int _generation = 0;
  StreamSubscription<void>? _changes;
  double _pinchStart = 1;

  CameraController? get controller => _controller;

  Future<void> start() async {
    emit(state.copyWith(opening: true, clearError: true, ready: false));
    final permission = await Permission.camera.request();
    if (permission.isDenied || permission.isPermanentlyDenied) {
      emit(
        state.copyWith(
          opening: false,
          ready: false,
          error: permission.isPermanentlyDenied
              ? 'Camera permission is blocked. Enable it in system settings.'
              : 'Camera permission is required to capture a batch.',
        ),
      );
      return;
    }
    try {
      _cameras = await availableCameras();
    } catch (error) {
      emit(
        state.copyWith(
          opening: false,
          ready: false,
          error: 'This device did not expose a camera.',
        ),
      );
      return;
    }
    if (_cameras.isEmpty) {
      emit(
        state.copyWith(
          opening: false,
          ready: false,
          error: 'No camera was found on this device.',
        ),
      );
      return;
    }
    _index = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    if (_index < 0) _index = 0;
    await _open(_cameras[_index]);
    await refreshBadge();
  }

  Future<void> refreshBadge() async {
    final badge = await repository.activeBatchBadge();
    if (isClosed) return;
    emit(
      state.copyWith(
        batchCount: badge.pending,
        thumbPath: badge.thumbPath,
        clearThumb: badge.thumbPath == null,
      ),
    );
  }

  Future<void> toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !state.flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      emit(state.copyWith(flashOn: next));
    } catch (_) {
      emit(state.copyWith(error: 'Flash is not available on this camera.'));
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    await _open(_cameras[_index]);
  }

  Future<void> setZoom(double zoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final clamped = zoom.clamp(state.minZoom, state.maxZoom).toDouble();
    try {
      await controller.setZoomLevel(clamped);
      emit(state.copyWith(zoom: clamped));
    } catch (_) {}
  }

  void beginPinch() => _pinchStart = state.zoom;

  Future<void> pinch(double scale) => setZoom(_pinchStart * scale);

  Future<void> setSlider(double t) async {
    final max = state.sliderMax;
    final zoom = 1 + t.clamp(0, 1) * (max - 1);
    await setZoom(zoom);
  }

  Future<void> setPreset(double preset) => setZoom(preset);

  Future<void> focusAt(Offset normalized) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    emit(
      state.copyWith(focus: normalized, focusSerial: state.focusSerial + 1),
    );
    try {
      await controller.setFocusPoint(normalized);
      await controller.setExposurePoint(normalized);
    } catch (_) {}
  }

  Future<void> capture() async {
    final controller = _controller;
    if (state.capturing ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    emit(state.copyWith(capturing: true, clearError: true));
    try {
      await HapticFeedback.mediumImpact();
      final shot = await controller.takePicture();
      await repository.saveCapture(shot.path);
      await refreshBadge();
      onCaptured?.call();
    } catch (_) {
      emit(
        state.copyWith(error: 'The shutter did not save a photo. Try again.'),
      );
    } finally {
      if (!isClosed) emit(state.copyWith(capturing: false));
    }
  }

  Future<void> pausePreview() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.pausePreview();
    } catch (_) {}
  }

  Future<void> resumePreview() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.resumePreview();
    } catch (_) {}
  }

  Future<void> openSettings() => openAppSettings();

  Future<void> _open(CameraDescription description) async {
    final generation = ++_generation;
    final previous = _controller;
    _controller = null;
    emit(state.copyWith(ready: false, opening: true, clearError: true));
    await previous?.dispose();
    if (generation != _generation || isClosed) return;

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (generation != _generation || isClosed) {
        await controller.dispose();
        return;
      }
      await controller.setFlashMode(FlashMode.off);
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final zoom = 1.0.clamp(minZoom, maxZoom).toDouble();
      await controller.setZoomLevel(zoom);
      _controller = controller;
      emit(
        state.copyWith(
          ready: true,
          opening: false,
          clearError: true,
          minZoom: minZoom,
          maxZoom: maxZoom,
          zoom: zoom,
          flashOn: false,
          session: state.session + 1,
        ),
      );
    } catch (_) {
      await controller.dispose();
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          ready: false,
          opening: false,
          error: 'The camera could not be opened.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _generation++;
    await _changes?.cancel();
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
    return super.close();
  }
}
