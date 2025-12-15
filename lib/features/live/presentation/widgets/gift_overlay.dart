import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/live_interaction_model.dart';

class GiftOverlay extends StatefulWidget {
  final Stream<LiveGift> giftStream;

  const GiftOverlay({super.key, required this.giftStream});

  @override
  State<GiftOverlay> createState() => _GiftOverlayState();
}

class _GiftOverlayState extends State<GiftOverlay>
    with TickerProviderStateMixin {
  final List<LiveGift> _giftQueue = [];
  LiveGift? _currentGift;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _isPlaying = false;

  final Map<String, String> _giftIcons = {
    'Rose': '🌹',
    'Heart': '❤️',
    'Mic': '🎤',
    'Panda': '🐼',
    'Car': '🏎️',
    'Castle': '🏰',
    'Rocket': '🚀',
    'Planet': '🪐',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    widget.giftStream.listen((gift) {
      _giftQueue.add(gift);
      if (!_isPlaying) {
        _playNextGift();
      }
    });
  }

  Future<void> _playNextGift() async {
    if (_giftQueue.isEmpty) {
      _isPlaying = false;
      return;
    }

    _isPlaying = true;
    setState(() {
      _currentGift = _giftQueue.removeAt(0);
    });

    // Animate In
    await _controller.forward(from: 0.0);

    // Hold
    await Future.delayed(const Duration(seconds: 2));

    // Animate Out (Fade/Slide or just disappear for next one)
    // We'll reverse for now
    await _controller.reverse();

    _playNextGift();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGift == null) return const SizedBox.shrink();

    return Positioned(
      top: 150,
      left: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.withOpacity(0.9),
                Colors.blue.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentGift!.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Sent a ${_currentGift!.giftName}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              ScaleTransition(
                scale: _scaleAnimation,
                child: Text(
                  _giftIcons[_currentGift!.giftName] ?? '🎁',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "x1",
                style: TextStyle(
                  color: Colors.yellowAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
