import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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

  // Dummy Video
  late VideoPlayerController _videoController;

  // Animations
  late AnimationController _heartAnimController;
  final List<Widget> _floatingHearts = [];

  @override
  void initState() {
    super.initState();
    // Agora logic preserved but disabled for now to prevent errors
    // _initAgora();
    // Simulate joined state for UI
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _joined = true);
    });

    _initDummyVideo();

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
        _showGiftAnimation(gift);
      }
    });
  }

  void _initDummyVideo() {
    // Using a sample video URL for demo purposes
    _videoController =
        VideoPlayerController.networkUrl(
            Uri.parse(
              'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
            ),
          )
          ..initialize().then((_) {
            // Ensure the first frame is shown after the video is initialized
            if (mounted) {
              setState(() {});
              _videoController.play();
              _videoController.setLooping(true);
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
          child: const Icon(Icons.favorite, color: Color(0xFFD900EE), size: 30),
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

  void _showGiftAnimation(LiveGift gift) {
    final animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Simple mapping for icons based on name (should be consistent with bottom sheet)
    String icon = '🎁';
    switch (gift.giftName) {
      case 'Rose':
        icon = '🌹';
        break;
      case 'Heart':
        icon = '❤️';
        break;
      case 'Mic':
        icon = '🎤';
        break;
      case 'Panda':
        icon = '🐼';
        break;
      case 'Car':
        icon = '🏎️';
        break;
      case 'Castle':
        icon = '🏰';
        break;
      case 'Rocket':
        icon = '🚀';
        break;
      case 'Planet':
        icon = '🪐';
        break;
    }

    Widget giftWidget = Center(
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: animation, curve: const Interval(0.7, 1.0)),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.5).animate(
            CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 100)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${gift.username} sent ${gift.giftName}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    setState(() {
      _floatingHearts.add(
        giftWidget,
      ); // Reusing _floatingHearts list for simplicity
    });

    animation.forward().then((value) {
      if (mounted) {
        setState(() {
          _floatingHearts.remove(giftWidget);
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
    // _liveService.leaveChannel(); // logic preserved
    _videoController.dispose();
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
          // Dummy Video Layer
          Center(
            child: _videoController.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: VideoPlayer(_videoController),
                  )
                : const CircularProgressIndicator(),
          ),

          // Agora Placeholder / Status (Preserved but hidden or repurposed)
          if (!_joined)
            Center(
              child: Text(
                "Joining Channel...",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),

          // Floating Hearts
          ..._floatingHearts,

          // Close Button (Top Right)
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
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
                                  color: Colors.white.withValues(alpha: 0.7),
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
                      textInputAction: TextInputAction.send,
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
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Color(0xFFD900EE),
                          ),
                          onPressed: _sendMessage,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.favorite,
                      color: Color(0xFFD900EE),
                      size: 40,
                    ),
                    onPressed: () {
                      _liveService.sendReaction();
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.card_giftcard,
                      color: Color(0xFFD900EE),
                      size: 30,
                    ),
                    onPressed: () {
                      _showGiftPicker(context);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showGiftPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftPickerBottomSheet(
        onGiftSent: (name, value) {
          _liveService.sendGift(name, value);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class GiftPickerBottomSheet extends StatefulWidget {
  final Function(String name, int value) onGiftSent;

  const GiftPickerBottomSheet({super.key, required this.onGiftSent});

  @override
  State<GiftPickerBottomSheet> createState() => _GiftPickerBottomSheetState();
}

class _GiftPickerBottomSheetState extends State<GiftPickerBottomSheet> {
  int _selectedIndex = -1;
  int _balance = 20; // Reduced initial balance for testing

  final List<Map<String, dynamic>> _gifts = [
    {'name': 'Rose', 'value': 1, 'icon': '🌹'},
    {'name': 'Heart', 'value': 5, 'icon': '❤️'},
    {'name': 'Mic', 'value': 10, 'icon': '🎤'},
    {'name': 'Panda', 'value': 50, 'icon': '🐼'},
    {'name': 'Car', 'value': 100, 'icon': '🏎️'},
    {'name': 'Castle', 'value': 500, 'icon': '🏰'},
    {'name': 'Rocket', 'value': 1000, 'icon': '🚀'},
    {'name': 'Planet', 'value': 5000, 'icon': '🪐'},
  ];

  void _showRechargeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Insufficient Coins",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "You don't have enough coins to send this gift. Recharge now?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD900EE),
            ),
            onPressed: () {
              // Placeholder for In-App Payment Logic
              setState(() {
                _balance += 1000; // Mock Recharge
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Recharge Successful! +1000 Coins"),
                  backgroundColor: Color(0xFFD900EE),
                ),
              );
            },
            child: const Text(
              "Recharge",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Send a Gift",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Balance: $_balance",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD900EE).withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD900EE)
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift['icon'],
                          style: const TextStyle(fontSize: 30),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          gift['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "${gift['value']}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Send Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD900EE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  disabledBackgroundColor: Colors.grey[800],
                ),
                onPressed: _selectedIndex == -1
                    ? null
                    : () {
                        final gift = _gifts[_selectedIndex];
                        if (_balance >= gift['value']) {
                          setState(() {
                            _balance -= gift['value'] as int;
                          });
                          widget.onGiftSent(gift['name'], gift['value']);
                        } else {
                          _showRechargeDialog();
                        }
                      },
                child: const Text(
                  "Send",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
