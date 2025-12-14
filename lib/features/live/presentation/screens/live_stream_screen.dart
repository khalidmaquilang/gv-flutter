import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/core/constants/api_constants.dart';
import '../../data/services/live_service.dart';
import '../../data/models/live_interaction_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/feed/presentation/providers/feed_audio_provider.dart';
import 'package:video_player/video_player.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  final bool isBroadcaster;
  final String channelId;

  const LiveStreamScreen({
    super.key,
    required this.isBroadcaster,
    required this.channelId,
  });

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen>
    with TickerProviderStateMixin {
  final _liveService = LiveService();
  late RtcEngine _engine;
  final List<LiveMessage> _messages = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isEngineReady = false;

  // Video Player for Audience
  VideoPlayerController? _videoController;

  // Animations
  late AnimationController _heartAnimController;

  @override
  void initState() {
    super.initState();
    if (widget.isBroadcaster) {
      _initAgora();
    } else {
      _initPlayer();
    }

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Listen to Streams (Mock for now)
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

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(ApiConstants.hlsPlayUrl),
      );
      await _videoController!.initialize();
      await _videoController!.play();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error initializing video player: $e");
    }
  }

  Future<void> _initAgora() async {
    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Create Engine
    _engine = createAgoraRtcEngine();

    // Initialize
    await _engine.initialize(
      const RtcEngineContext(
        appId: ApiConstants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    // Define handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint("remote user $remoteUid left channel");
            },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('On Token Privilege Will Expire: $token');
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora Error: $err, $msg');
        },
      ),
    );

    // Set Client Role
    await _engine.setClientRole(
      role: widget.isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    // Enable Video
    await _engine.enableVideo();
    await _engine.startPreview();

    if (mounted) {
      setState(() {
        _isEngineReady = true;
      });
    }

    // Join Channel
    await _engine.joinChannel(
      token: ApiConstants.agoraTempToken,
      channelId: widget.channelId,
      uid: 0, // 0 means Let Agora assign one
      options: const ChannelMediaOptions(),
    );
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

  @override
  void dispose() {
    _heartAnimController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    _videoController?.dispose();

    if (widget.isBroadcaster) {
      try {
        _engine.leaveChannel();
        _engine.release();
      } catch (e) {
        // ignore
      }
    }

    // Restore Feed Audio when leaving the stream
    ref.read(isFeedAudioEnabledProvider.notifier).state = true;

    super.dispose();
  }

  // Helper to show heart animation
  void _showHeartAnimation() {
    _heartAnimController.forward(from: 0).then((_) {
      _heartAnimController.reset();
    });
  }

  void _showGiftAnimation(LiveGift gift) {
    // Gift animation logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${gift.username} sent ${gift.giftName}!")),
    );
  }

  void _sendMessage() {
    if (_commentController.text.trim().isEmpty) return;

    // Correct Model Usage
    final msg = LiveMessage(username: 'Me', message: _commentController.text);

    setState(() {
      _messages.add(msg);
    });
    _commentController.clear();
    _scrollToBottom();
  }

  void _sendHeart() {
    _liveService.sendReaction();
    _showHeartAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Layer
          Center(
            child: widget.isBroadcaster
                ? _renderBroadcasterVideo()
                : _renderAudienceVideo(),
          ),

          // Close/End Button
          Positioned(
            top: 40,
            right: 20,
            child: widget.isBroadcaster
                ? GestureDetector(
                    onTap: () {
                      // Confirm End Live
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("End Live Stream?"),
                          content: const Text(
                            "Are you sure you want to end your live?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx); // Close dialog
                                Navigator.pop(context); // Close screen
                              },
                              child: const Text(
                                "End",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "End Live",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
          ),

          // Live Tag
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.neonPink,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Bottom Content Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Comments Area
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "${msg.username}: ",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
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

                  // Input Area
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Say something...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Heart Button (Visible to all)
                      IconButton(
                        icon: const Icon(
                          Icons.favorite,
                          color: AppColors.neonPink,
                        ),
                        onPressed: _sendHeart,
                      ),
                      // Gift Button (Hidden for Broadcaster)
                      if (!widget.isBroadcaster)
                        IconButton(
                          icon: const Icon(
                            Icons.card_giftcard,
                            color: Colors.amber,
                          ),
                          onPressed: () => _showGiftPicker(context),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderBroadcasterVideo() {
    if (_isEngineReady) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0), // 0 for local user
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _renderAudienceVideo() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
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
  int _balance = 20;

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
              backgroundColor: AppColors.neonPink,
            ),
            onPressed: () {
              // Placeholder for In-App Payment Logic
              setState(() {
                _balance += 1000;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Recharge Successful! +1000 Coins"),
                  backgroundColor: AppColors.neonPink,
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
                          ? AppColors.neonPink.withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.neonPink
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
                  backgroundColor: AppColors.neonPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  disabledBackgroundColor: Colors.grey[800],
                ),
                onPressed: _selectedIndex == -1
                    ? null
                    : () {
                        final gift = _gifts[_selectedIndex];
                        if (_balance >= (gift['value'] as int)) {
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
