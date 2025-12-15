import 'dart:math';
import 'package:flutter/material.dart';

class FloatingHeartsOverlay extends StatefulWidget {
  final Stream<void> triggerStream;

  const FloatingHeartsOverlay({super.key, required this.triggerStream});

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay>
    with TickerProviderStateMixin {
  final List<_Heart> _hearts = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    widget.triggerStream.listen((_) {
      _addHeart();
    });
  }

  void _addHeart() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    final heart = _Heart(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      controller: controller,
      color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
      xOffset: (_random.nextDouble() * 100) - 50, // -50 to 50
    );

    setState(() {
      _hearts.add(heart);
    });

    controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _hearts.removeWhere((h) => h.id == heart.id);
        });
      }
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (var heart in _hearts) {
      heart.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _hearts.map((heart) {
        return AnimatedBuilder(
          animation: heart.controller,
          builder: (context, child) {
            final value = heart.controller.value;
            // Start near bottom (80) and float up to 400
            final bottom = 80.0 + (value * 300);
            final opacity = 1.0 - value;
            final scale = 1.0 + (value * 0.5);

            return Positioned(
              bottom: bottom,
              right:
                  20 + heart.xOffset, // Closer to right edge (button position)
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Icon(Icons.favorite, color: heart.color, size: 30),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _Heart {
  final String id;
  final AnimationController controller;
  final Color color;
  final double xOffset;

  _Heart({
    required this.id,
    required this.controller,
    required this.color,
    required this.xOffset,
  });
}
