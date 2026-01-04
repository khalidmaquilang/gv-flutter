import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'roulette_pointer.dart';

class RouletteItem {
  final String text;
  final Color color;
  final IconData? icon;

  const RouletteItem({required this.text, required this.color, this.icon});
}

class RouletteWheel extends StatefulWidget {
  final List<RouletteItem> items;
  final Function(int) onSpinEnd;

  const RouletteWheel({
    super.key,
    required this.items,
    required this.onSpinEnd,
  });

  @override
  State<RouletteWheel> createState() => _RouletteWheelState();
}

class _RouletteWheelState extends State<RouletteWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentRotation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.decelerate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void spin() {
    if (_controller.isAnimating) return;

    // Spin at least 5 full rotations + random segment
    final random = Random();
    // final nextIndex = random.nextInt(widget.items.length);

    // Calculate the angle to land on the center of the target item
    // final segmentAngle = 2 * pi / widget.items.length;

    // final extraSpins = 5 + random.nextInt(3);

    // This math is tricky to get exact index. Let's simplify:
    // Just pick a random total rotation, then calculate winner from that.

    final totalRotation =
        _currentRotation + (2 * pi * 5) + (random.nextDouble() * 2 * pi);

    final tween = Tween<double>(begin: _currentRotation, end: totalRotation);

    _animation = tween.animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _currentRotation = totalRotation;
      });
      _calculateWinner(totalRotation);
    });
  }

  void _calculateWinner(double finalRotation) {
    // Normalize rotation to 0..2pi
    double normalized = finalRotation % (2 * pi);

    // Winner Index Logic
    int winnerIndex =
        ((widget.items.length - (normalized / (2 * pi / widget.items.length))) %
                widget.items.length)
            .floor();

    widget.onSpinEnd(winnerIndex);
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wheel and Pointer Stack
        SizedBox(
          height: 350, // Slightly improved headroom for pointer
          width: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The Spinning Wheel
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _animation.value,
                          child: CustomPaint(
                            painter: _RoulettePainter(widget.items),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // The Physics Pointer (Internalized)
              Positioned(
                top: 0,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return RoulettePointer(
                      rotation: _animation.value,
                      itemCount: widget.items.length,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: spin,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF00FFC2),
                  Color(0xFF00B8FF),
                ], // Neon Cyan -> Blue
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFC2).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Text(
              "SPIN",
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoulettePainter extends CustomPainter {
  final List<RouletteItem> items;

  _RoulettePainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    // Inner wheel radius (leaving space for outer ring)
    final wheelRadius = radius * 0.9;
    final rect = Rect.fromCircle(center: center, radius: wheelRadius);

    final segmentAngle = 2 * pi / items.length;

    // 1. Draw Outer Ring (Casino Style)
    _drawOuterRing(canvas, center, radius, wheelRadius);

    // 2. Wheel Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, wheelRadius - 2, shadowPaint);

    final paint = Paint()..style = PaintingStyle.fill;

    // We start drawing from -pi/2 (Top) so Index 0 is at Top initially.
    double startAngle = -pi / 2;

    for (int i = 0; i < items.length; i++) {
      // Segment Gradient (Simulate curvature)
      final segmentGradient = RadialGradient(
        colors: [
          items[i].color.withOpacity(0.8),
          items[i].color,
          items[i].color
              .withBlue(max(0, items[i].color.blue - 40))
              .withGreen(max(0, items[i].color.green - 40))
              .withRed(max(0, items[i].color.red - 40)), // Darker at edge
        ],
        stops: const [0.0, 0.7, 1.0],
        center: Alignment.center,
        radius: 0.8,
      );

      paint.shader = segmentGradient.createShader(rect);

      canvas.drawArc(rect, startAngle, segmentAngle, true, paint);

      // Separator Lines (Neon/Metallic)
      _drawSeparator(canvas, center, wheelRadius, startAngle);

      // Draw Text/Icon
      _drawContent(
        canvas,
        center,
        wheelRadius,
        startAngle + segmentAngle / 2,
        items[i],
      );

      startAngle += segmentAngle;
    }

    // 3. Center Hub (Fancy)
    _drawCenterHub(canvas, center);
  }

  void _drawOuterRing(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double innerRadius,
  ) {
    // Ring Body
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerRadius - innerRadius
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF222222),
          Color(0xFF444444),
          Color(0xFF222222),
          Color(0xFF111111),
          Color(0xFF222222),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

    canvas.drawCircle(
      center,
      outerRadius - (outerRadius - innerRadius) / 2,
      ringPaint,
    );

    // Lights on the ring
    const lightCount = 20;
    final lightRadius = (outerRadius - innerRadius) * 0.15;
    final ringMidRadius = innerRadius + (outerRadius - innerRadius) / 2;

    for (int i = 0; i < lightCount; i++) {
      double angle = (2 * pi / lightCount) * i;
      double lx = center.dx + ringMidRadius * cos(angle);
      double ly = center.dy + ringMidRadius * sin(angle);

      // Glow
      canvas.drawCircle(
        Offset(lx, ly),
        lightRadius + 2,
        Paint()
          ..color = Colors.amber.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // Bulb
      canvas.drawCircle(
        Offset(lx, ly),
        lightRadius,
        Paint()
          ..color = (i % 2 == 0) ? Colors.amberAccent : Colors.yellowAccent,
      );
    }
  }

  void _drawSeparator(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
  ) {
    final sepPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dx = center.dx + radius * cos(angle);
    final dy = center.dy + radius * sin(angle);

    canvas.drawLine(center, Offset(dx, dy), sepPaint);

    // Highlight line
    canvas.drawLine(
      center,
      Offset(dx, dy),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );
  }

  void _drawCenterHub(Canvas canvas, Offset center) {
    // Gold/ Metallic Rim
    canvas.drawCircle(center, 22, Paint()..color = const Color(0xFFB8860B));
    canvas.drawCircle(center, 20, Paint()..color = const Color(0xFF1a1a1a));

    // Logo or Star in center
    const textSpan = TextSpan(
      text: "★",
      style: TextStyle(color: Colors.amber, fontSize: 18),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _drawContent(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    RouletteItem item,
  ) {
    final distance = radius * 0.65;
    final x = center.dx + distance * cos(angle);
    final y = center.dy + distance * sin(angle);

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle + pi / 2); // Rotate text to face center

    final textSpan = TextSpan(
      text: item.text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        shadows: [
          Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1)),
        ],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );

    // Calculate max available width based on segment size at this radius
    // Arc length ~= radius * angle
    final maxWidth = distance * (2 * pi / items.length) * 0.8;

    textPainter.layout(maxWidth: maxWidth);

    // Center text at (0,0) which is (x,y)
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    // If Icon
    if (item.icon != null) {
      // Draw icon logic could go here, for now simpler with just text or text+icon logic
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
