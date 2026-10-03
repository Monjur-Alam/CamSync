import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_route.dart';
import '../../bloc/camera/camera_cubit.dart';
import '../../bloc/camera/camera_state.dart';
import '../../bloc/sync/sync_cubit.dart';
import '../../bloc/sync/sync_state.dart';
import '../../core/theme/misurl_colors.dart';
import '../upload/upload_manager_screen.dart';
import 'camera_controls.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      misurlRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    misurlRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    context.read<CameraCubit>().pausePreview();
  }

  @override
  void didPopNext() {
    context.read<CameraCubit>().resumePreview();
  }

  void _openUploads() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const UploadManagerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MisurlColors.preview,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const _CameraPreview(),
                const _Scrim(),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(child: _TopBar()),
                ),
                Positioned(
                  top: constraints.maxHeight * 0.145,
                  left: 0,
                  right: 0,
                  child: const _Watermark(),
                ),
                const Positioned.fill(child: _FocusLayer()),
                Positioned(
                  right: 14,
                  bottom: constraints.maxHeight * 0.31,
                  child: const _ZoomRailSlot(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomCluster(onOpenUploads: _openUploads),
                ),
                const _ErrorBanner(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, next) =>
          previous.ready != next.ready || previous.session != next.session,
      builder: (context, state) {
        final controller = context.read<CameraCubit>().controller;
        if (!state.ready ||
            controller == null ||
            !controller.value.isInitialized) {
          return const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5C7677), MisurlColors.previewDeep],
              ),
            ),
          );
        }
        final preview = controller.value.previewSize;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final size = box.size;
            context.read<CameraCubit>().focusAt(
              Offset(
                (local.dx / size.width).clamp(0.02, 0.98),
                (local.dy / size.height).clamp(0.08, 0.72),
              ),
            );
          },
          onScaleStart: (_) => context.read<CameraCubit>().beginPinch(),
          onScaleUpdate: (details) {
            if (details.pointerCount < 2) return;
            context.read<CameraCubit>().pinch(details.scale);
          },
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: preview == null ? 1 : preview.height,
                height: preview == null ? 1 : preview.width,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x66000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0x99000000),
            ],
            stops: [0, 0.22, 0.58, 1],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.close,
            onPressed: () => SystemNavigator.pop(),
          ),
          const Spacer(),
          BlocBuilder<CameraCubit, CameraState>(
            buildWhen: (previous, next) => previous.flashOn != next.flashOn,
            builder: (context, state) {
              return IconButton(
                onPressed: () => context.read<CameraCubit>().toggleFlash(),
                icon: Icon(
                  Icons.bolt,
                  color: state.flashOn
                      ? const Color(0xFFFFD15C)
                      : Colors.white,
                  size: 26,
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: MisurlColors.navyRaised,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const _LinkSheet(),
            ),
            icon: const Icon(Icons.settings, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class _Watermark extends StatelessWidget {
  const _Watermark();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Text(
        'MISURL',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xD9FFFFFF),
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 6,
        ),
      ),
    );
  }
}

class _FocusLayer extends StatelessWidget {
  const _FocusLayer();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, next) =>
          previous.focus != next.focus ||
          previous.focusSerial != next.focusSerial,
      builder: (context, state) {
        final focus = state.focus;
        if (focus == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  left: focus.dx * constraints.maxWidth - 36,
                  top: focus.dy * constraints.maxHeight - 36,
                  child: IgnorePointer(
                    child: FocusRing(serial: state.focusSerial),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ZoomRailSlot extends StatelessWidget {
  const _ZoomRailSlot();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, next) =>
          previous.zoom != next.zoom ||
          previous.maxZoom != next.maxZoom ||
          previous.ready != next.ready,
      builder: (context, state) {
        return ZoomRail(
          zoom: state.zoom,
          sliderMax: state.sliderMax,
          onChanged: state.ready
              ? (value) => context.read<CameraCubit>().setSlider(value)
              : (_) {},
        );
      },
    );
  }
}

class _BottomCluster extends StatelessWidget {
  const _BottomCluster({required this.onOpenUploads});

  final VoidCallback onOpenUploads;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: BlocBuilder<CameraCubit, CameraState>(
            buildWhen: (previous, next) =>
                previous.zoom != next.zoom ||
                previous.batchCount != next.batchCount ||
                previous.thumbPath != next.thumbPath ||
                previous.capturing != next.capturing ||
                previous.ready != next.ready,
            builder: (context, state) {
              final preset = selectedPreset(state.zoom);
              final cubit = context.read<CameraCubit>();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < zoomPresets.length; i++) ...[
                        ZoomChip(
                          label: zoomPresets[i].label,
                          selected: preset == zoomPresets[i].value,
                          onTap: () => cubit.setPreset(zoomPresets[i].value),
                        ),
                        if (i != zoomPresets.length - 1)
                          const SizedBox(width: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BatchThumbnail(
                        path: state.thumbPath,
                        count: state.batchCount,
                        onTap: onOpenUploads,
                      ),
                      ShutterButton(
                        busy: state.capturing,
                        onPressed: state.ready ? cubit.capture : () {},
                      ),
                      RoundIconButton(
                        icon: Icons.flip_camera_ios,
                        size: 46,
                        onPressed: cubit.switchCamera,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'LIVE VIEW',
                    style: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MisurlColors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: onOpenUploads,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.anchor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'UPLOAD BATCH (${state.batchCount})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraCubit, CameraState>(
      buildWhen: (previous, next) =>
          previous.error != next.error ||
          previous.opening != next.opening ||
          previous.ready != next.ready,
      builder: (context, state) {
        if (state.opening || state.error == null || state.ready) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.read<CameraCubit>().start(),
                  child: const Text('TRY AGAIN'),
                ),
                TextButton(
                  onPressed: () => context.read<CameraCubit>().openSettings(),
                  child: const Text('SYSTEM SETTINGS'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinkSheet extends StatelessWidget {
  const _LinkSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, state) {
        final pending = state.pendingCount;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MisurlColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                state.linkStable ? 'STABLE LINK' : 'NO LINK',
                style: TextStyle(
                  color: state.linkStable
                      ? MisurlColors.green
                      : MisurlColors.linkDown,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.paused
                    ? 'Sync is paused. $pending capture${pending == 1 ? '' : 's'} still in the queue.'
                    : '$pending capture${pending == 1 ? '' : 's'} waiting on this phone.',
                style: const TextStyle(color: MisurlColors.body),
              ),
            ],
          ),
        );
      },
    );
  }
}
