import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class CameraState extends Equatable {
  const CameraState({
    this.ready = false,
    this.opening = true,
    this.error,
    this.zoom = 1,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.flashOn = false,
    this.batchCount = 0,
    this.thumbPath,
    this.focus,
    this.focusSerial = 0,
    this.capturing = false,
    this.session = 0,
  });

  final bool ready;
  final bool opening;
  final String? error;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final bool flashOn;
  final int batchCount;
  final String? thumbPath;
  final Offset? focus;
  final int focusSerial;
  final bool capturing;
  final int session;

  double get sliderMax => maxZoom < 1 ? 1 : (maxZoom < 5 ? maxZoom : 5);

  CameraState copyWith({
    bool? ready,
    bool? opening,
    String? error,
    bool clearError = false,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    bool? flashOn,
    int? batchCount,
    String? thumbPath,
    bool clearThumb = false,
    Offset? focus,
    bool clearFocus = false,
    int? focusSerial,
    bool? capturing,
    int? session,
  }) {
    return CameraState(
      ready: ready ?? this.ready,
      opening: opening ?? this.opening,
      error: clearError ? null : (error ?? this.error),
      zoom: zoom ?? this.zoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      flashOn: flashOn ?? this.flashOn,
      batchCount: batchCount ?? this.batchCount,
      thumbPath: clearThumb ? null : (thumbPath ?? this.thumbPath),
      focus: clearFocus ? null : (focus ?? this.focus),
      focusSerial: focusSerial ?? this.focusSerial,
      capturing: capturing ?? this.capturing,
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props => [
    ready,
    opening,
    error,
    zoom,
    minZoom,
    maxZoom,
    flashOn,
    batchCount,
    thumbPath,
    focus,
    focusSerial,
    capturing,
    session,
  ];
}
