import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/services/live_service.dart';
import '../../data/models/live_interaction_model.dart';

class LiveStreamScreen extends StatefulWidget {
  final bool isBroadcaster;
  final String channelId;

  const LiveStreamScreen({
    super.key,
    required this.isBroadcaster,
    required this.channelId,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with TickerProviderStateMixin {
  final _liveService = LiveService(); // Should use provider
  bool _joined = false;
  final List<LiveMessage> _messages = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animations
  late AnimationController _heartAnimController;
  final List<Widget> _floatingHearts = [];

  @override
  void initState() {
    super.initState();
    _initAgora();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Listen to Streams
    _liveService.messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
        _scrollToBottom();
      }
    });

    _liveService.reactionStream.listen((reaction) {
      if (mounted) _showHeartAnimation();
    });

    _liveService.giftStream.listen((gift) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${gift.username} sent ${gift.giftName}!"),
            backgroundColor: const Color(0xFFFE2C55),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showHeartAnimation() {
    final animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    Widget heart = Positioned(
      bottom: 100,
      right: 16 + (Random().nextInt(20).toDouble()),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0, -5),
          ).animate(animation),
          child: const Icon(Icons.favorite, color: Color(0xFFFE2C55), size: 30),
        ),
      ),
    );

    setState(() {
      _floatingHearts.add(heart);
    });

    animation.forward().then((value) {
      if (mounted) {
        setState(() {
          _floatingHearts.remove(heart);
        });
      }
      animation.dispose();
    });
  }

  Future<void> _initAgora() async {
    // Mock init
    await _liveService.initialize(onEvent: (event) {});
    await _liveService.joinChannel(
      widget.channelId,
      "TOKEN",
      widget.isBroadcaster,
    );
    setState(() {
      _joined = true;
    });
  }

  void _sendMessage() {
    if (_commentController.text.isNotEmpty) {
      _liveService.sendComment(_commentController.text);
      _commentController.clear();
    }
  }

  @override
  void dispose() {
    _liveService.leaveChannel();
    _heartAnimController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _joined
                ? Text(
                    widget.isBroadcaster ? "Broadcasting..." : "Watching...",
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  )
                : const CircularProgressIndicator(),
          ),

          // Floating Hearts
          ..._floatingHearts,

          if (widget.isBroadcaster)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 40),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

          // Live Chat Overlay
          Positioned(
            bottom: 100,
            left: 16,
            height: 250,
            width: 250,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "${msg.username}: ",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: msg.message,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Bottom Input Bar (Audience)
          if (!widget.isBroadcaster)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Say something...",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      _liveService.sendReaction();
                      // _showHeartAnimation(); // Local immediate feedback is handled by stream listener too, but can force it here
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.card_giftcard,
                      color: Color(0xFFFE2C55),
                      size: 30,
                    ),
                    onPressed: () {
                      _liveService.sendGift();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
