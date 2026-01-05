import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/features/live/domain/models/gift_item.dart';
import 'package:test_flutter/features/live/presentation/managers/gift_manager.dart';

class GiftAnimationOverlay extends StatefulWidget {
  const GiftAnimationOverlay({super.key});

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay> {
  GiftMessage? _currentGift;

  @override
  void initState() {
    super.initState();
    // Listen to gift animation stream
    GiftManager().animationStream.listen((giftMessage) {
      if (mounted) {
        setState(() {
          _currentGift = giftMessage;
        });

        // Auto-dismiss after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _currentGift = null;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGift == null) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _currentGift != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.neonPink.withValues(alpha: 0.9),
                  AppColors.neonCyan.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPink.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gift emoji with animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value * 6.28 * 2, // 2 full rotations
                      child: Text(
                        _currentGift!.gift.emoji,
                        style: const TextStyle(fontSize: 80),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Sender name
                Text(
                  _currentGift!.senderUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Gift info
                Text(
                  'sent ${_currentGift!.count > 1 ? '${_currentGift!.count}x ' : ''}${_currentGift!.gift.name}${_currentGift!.count > 1 ? 's' : ''}!',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
