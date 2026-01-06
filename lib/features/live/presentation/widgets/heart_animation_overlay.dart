import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:test_flutter/core/theme/app_theme.dart';

/// Overlay widget that displays rising heart animations
class HeartAnimationOverlay extends StatefulWidget {
  const HeartAnimationOverlay({super.key});

  @override
  State<HeartAnimationOverlay> createState() => _HeartAnimationOverlayState();
}

class _HeartAnimationOverlayState extends State<HeartAnimationOverlay> {
  final List<_HeartAnimation> _activeHearts = [];
  final math.Random _random = math.Random();

  /// Add a new heart animation
  void addHeart() {
    if (!mounted) return;

    setState(() {
      _activeHearts.add(
        _HeartAnimation(
          id: DateTime.now().millisecondsSinceEpoch,
          startX: _random.nextDouble() * 0.8 + 0.1, // 10-90% of screen width
          duration: Duration(milliseconds: 2000 + _random.nextInt(1000)),
        ),
      );
    });

    // Remove heart after animation completes
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _activeHearts.removeWhere(
            (h) => h.id == _activeHearts.firstOrNull?.id,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _activeHearts.map((heart) {
        return _RisingHeart(
          key: ValueKey(heart.id),
          startX: heart.startX,
          duration: heart.duration,
        );
      }).toList(),
    );
  }
}

/// Data class for heart animation
class _HeartAnimation {
  final int id;
  final double startX;
  final Duration duration;

  _HeartAnimation({
    required this.id,
    required this.startX,
    required this.duration,
  });
}

/// Individual rising heart widget
class _RisingHeart extends StatefulWidget {
  final double startX;
  final Duration duration;

  const _RisingHeart({super.key, required this.startX, required this.duration});

  @override
  State<_RisingHeart> createState() => _RisingHeartState();
}

class _RisingHeartState extends State<_RisingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _verticalAnimation;
  late Animation<double> _horizontalAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late double _horizontalOffset;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Random horizontal drift
    _horizontalOffset = (_random.nextDouble() - 0.5) * 100;

    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Vertical movement (bottom to top)
    _verticalAnimation = Tween<double>(
      begin: 0.0,
      end: -1.0, // Move up entire screen
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Horizontal drift (subtle wave motion)
    _horizontalAnimation = Tween<double>(
      begin: 0.0,
      end: _horizontalOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Scale animation (grow slightly then shrink)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.5), weight: 60),
    ]).animate(_controller);

    // Fade out at the end
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left:
              MediaQuery.of(context).size.width * widget.startX +
              _horizontalAnimation.value,
          bottom:
              MediaQuery.of(context).size.height * 0.1 +
              (-_verticalAnimation.value * MediaQuery.of(context).size.height),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(
                Icons.favorite,
                color: AppColors.neonPink,
                size: 40,
                shadows: [
                  Shadow(
                    color: AppColors.neonPink.withValues(alpha: 0.8),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Global key to access the heart overlay state
final GlobalKey<_HeartAnimationOverlayState> heartOverlayKey =
    GlobalKey<_HeartAnimationOverlayState>();
