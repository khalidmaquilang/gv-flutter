import 'dart:math';
import 'package:flutter/material.dart';

class RoulettePointer extends StatelessWidget {
  final double rotation;
  final int itemCount;

  const RoulettePointer({
    super.key,
    required this.rotation,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate how many segments have passed
    // rotation is in radians. 2pi = 1 full turn.
    // segments per turn = itemCount.
    // Total segments passed = rotation / (2pi / itemCount) = rotation * itemCount / 2pi

    final segmentAngle = 2 * pi / itemCount;

    // We want the "kick" to happen every time a segment boundary passes Top (-pi/2 or 3pi/2).
    // Let's look at relative position within a segment.

    final relativePos = (rotation / segmentAngle);
    // fractional part goes 0..1 then resets.

    final progress = relativePos - relativePos.floor();

    // We want a motion that:
    // - Slowly rises (dragged by peg)
    // - Snaps back (released)

    // Sawtooth wave:
    // angle = kickAmount * progress
    // But we probably want it to look like it hits and bounces.

    // Let's try:
    // Angle increases as progress goes 0.8 -> 1.0 (peg hitting)
    // Snaps back at 0.0

    // Let's use a "Sawtooth" for mechanical feel
    // Dragged slightly, then snap.
    final mechanicalAngle =
        -0.15 * sin(progress * 2 * pi); // Oscillates once per segment

    return Transform.rotate(
      angle: mechanicalAngle,
      alignment: Alignment
          .topCenter, // Pivot at top where it's attached? No, pivot at center of itself?
      // Pointer is typically pinned at the very top of the wheel.
      // Ideally pivot is at the "nail" holding the pointer.
      origin: const Offset(0, -20), // Move pivot point up
      child: SizedBox(
        width: 50,
        height: 60,
        child: CustomPaint(
          painter: _PointerPainter(),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Metallic Gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFFFFE0), // Pale Gold
        const Color(0xFFDAA520), // Goldenrod
        const Color(0xFFB8860B), // Dark Goldenrod
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final path = Path();
    // Inverted Triangle / Marker shape
    path.moveTo(size.width / 2, size.height); // Tip at bottom
    path.lineTo(size.width, 0); // Top Right
    path.quadraticBezierTo(size.width / 2, 10, 0, 0); // Top curve
    path.close();

    paint.shader = gradient.createShader(Offset.zero & size);

    // Draw Shadow
    canvas.drawShadow(path, Colors.black, 4, true);

    canvas.drawPath(path, paint);

    // Add inner detail/highlight
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawPath(path, borderPaint);

    // Central Gem/Neon
    final centerEffect = Paint()
      ..color = Colors.cyanAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(size.width / 2, 15), 5, centerEffect);

    canvas.drawCircle(
      Offset(size.width / 2, 15),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
