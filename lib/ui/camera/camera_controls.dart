import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/misurl_colors.dart';

class ZoomRail extends StatelessWidget {
  const ZoomRail({
    super.key,
    required this.zoom,
    required this.sliderMax,
    required this.onChanged,
  });

  final double zoom;
  final double sliderMax;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final span = (sliderMax - 1).clamp(0.01, 5);
    final t = ((zoom.clamp(1, sliderMax) - 1) / span).clamp(0.0, 1.0);
    final top = sliderMax >= 4.9 ? '5x' : _label(sliderMax);
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(top, style: _labelStyle),
          const SizedBox(height: 8),
          SizedBox(
            height: 148,
            width: 46,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final local = box.globalToLocal(details.globalPosition);
                    final next = 1 - (local.dy / constraints.maxHeight);
                    onChanged(next.clamp(0.0, 1.0));
                  },
                  onTapDown: (details) {
                    final next =
                        1 - (details.localPosition.dy / constraints.maxHeight);
                    onChanged(next.clamp(0.0, 1.0));
                  },
                  child: CustomPaint(
                    painter: _ZoomTrackPainter(t: t),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text('1x', style: _labelStyle),
        ],
      ),
    );
  }

  static String _label(double zoom) {
    final text = zoom.toStringAsFixed(zoom >= 10 ? 0 : 1);
    return text.endsWith('.0') ? '${zoom.toStringAsFixed(0)}x' : '${text}x';
  }
}

const _labelStyle = TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.w600,
);

class _ZoomTrackPainter extends CustomPainter {
  const _ZoomTrackPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    const inset = 8.0;
    canvas.drawLine(
      Offset(x, inset),
      Offset(x, size.height - inset),
      track,
    );
    final thumbY = inset + (1 - t) * (size.height - inset * 2);
    canvas.drawCircle(
      Offset(x, thumbY),
      7.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(x, thumbY),
      7.5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ZoomTrackPainter oldDelegate) =>
      oldDelegate.t != t;
}

class ZoomPreset {
  const ZoomPreset(this.value, this.label);

  final double value;
  final String label;
}

const zoomPresets = [
  ZoomPreset(0.5, '0.5'),
  ZoomPreset(1, '1x'),
  ZoomPreset(2, '2'),
];

double? selectedPreset(double zoom) {
  double? best;
  var distance = 0.22;
  for (final preset in zoomPresets) {
    final gap = (zoom - preset.value).abs();
    if (gap < distance) {
      distance = gap;
      best = preset.value;
    }
  }
  return best;
}

class ZoomChip extends StatelessWidget {
  const ZoomChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 42.0 : 36.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? Colors.white
              : Colors.black.withValues(alpha: 0.45),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: selected ? 13 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class ShutterButton extends StatefulWidget {
  const ShutterButton({super.key, required this.onPressed, required this.busy});

  final VoidCallback onPressed;
  final bool busy;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final inner = _down || widget.busy ? 50.0 : 58.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onPressed();
      },
      child: Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: inner,
          height: inner,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.serial});

  final int serial;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void didUpdateWidget(FocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serial != widget.serial) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.55, 1),
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.25, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: const CustomPaint(
          size: Size.square(72),
          painter: _BracketPainter(),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const arm = 16.0;
    final path = Path()
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      ..moveTo(size.width - arm, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, arm)
      ..moveTo(size.width, size.height - arm)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - arm, size.height)
      ..moveTo(arm, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.48),
        ),
      ),
    );
  }
}

class BatchThumbnail extends StatelessWidget {
  const BatchThumbnail({
    super.key,
    required this.path,
    required this.count,
    required this.onTap,
  });

  final String? path;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 58,
              height: 58,
              margin: const EdgeInsets.only(top: 6),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: MisurlColors.thumbWell,
                borderRadius: BorderRadius.circular(14),
              ),
              child: path == null
                  ? const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF2C2C2C),
                    )
                  : Image.file(
                      File(path!),
                      fit: BoxFit.cover,
                      cacheWidth: 180,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: 0,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MisurlColors.progress,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
