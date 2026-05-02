import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';

enum SpotlightShape { rect, circle }

enum TooltipPosition { above, below }

class CoachMark {
  CoachMark({
    required this.targetKey,
    required this.title,
    required this.body,
    this.shape = SpotlightShape.rect,
    this.tooltipPosition = TooltipPosition.below,
    this.padding = 8,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final SpotlightShape shape;
  final TooltipPosition tooltipPosition;
  final double padding;
}

class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  final List<CoachMark> steps;
  final VoidCallback onFinish;

  static void show(
    BuildContext context, {
    required List<CoachMark> steps,
    VoidCallback? onFinish,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CoachMarkOverlay(
        steps: steps,
        onFinish: () {
          entry.remove();
          onFinish?.call();
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _i = 0;

  Rect? _targetRect() {
    final ctx = widget.steps[_i].targetKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

  void _next() {
    if (_i >= widget.steps.length - 1) {
      _close();
    } else {
      setState(() => _i++);
    }
  }

  void _close() {
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final rect = _targetRect();
    final size = MediaQuery.of(context).size;
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _next,
            child: CustomPaint(
              painter: _Backdrop(
                rect: rect?.inflate(step.padding),
                shape: step.shape,
              ),
            ),
          ),
          if (rect != null)
            Positioned(
              left: step.tooltipPosition == TooltipPosition.below
                  ? (rect.left).clamp(20, size.width - 280).toDouble()
                  : (rect.left).clamp(20, size.width - 280).toDouble(),
              top: step.tooltipPosition == TooltipPosition.below
                  ? rect.bottom + 16
                  : rect.top - 130,
              width: 280,
              child: _Tooltip(
                title: step.title,
                body: step.body,
                index: _i,
                total: widget.steps.length,
                onNext: _next,
                onSkip: _close,
              ),
            )
          else
            Center(
              child: _Tooltip(
                title: step.title,
                body: step.body,
                index: _i,
                total: widget.steps.length,
                onNext: _next,
                onSkip: _close,
              ),
            ),
        ],
      ),
    );
  }
}

class _Backdrop extends CustomPainter {
  _Backdrop({required this.rect, required this.shape});

  final Rect? rect;
  final SpotlightShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.78);
    if (rect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path();
    if (shape == SpotlightShape.circle) {
      hole.addOval(rect!);
    } else {
      hole.addRRect(
        RRect.fromRectAndRadius(rect!, const Radius.circular(12)),
      );
    }
    final cutout = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(cutout, paint);

    // Glow border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.accent.withValues(alpha: 0.85);
    if (shape == SpotlightShape.circle) {
      canvas.drawOval(rect!, border);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect!, const Radius.circular(12)),
        border,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Backdrop oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.shape != shape;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.title,
    required this.body,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final String title;
  final String body;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.gray,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${index + 1} / $total',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.gray,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: onNext,
                child: Text(index == total - 1 ? 'Done' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
