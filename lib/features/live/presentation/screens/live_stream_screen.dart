import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/core/constants/api_constants.dart';
import '../../data/services/live_service.dart';
import '../../data/models/live_interaction_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/feed/presentation/providers/feed_audio_provider.dart';
import 'package:video_player/video_player.dart' hide VideoFormat;
import '../../data/services/media_push_service.dart';
import '../widgets/gift_overlay.dart';
import '../widgets/floating_hearts_overlay.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

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
  final List<LiveMessage> _messages = [];
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Agora Engine
  late RtcEngine _engine;
  bool _isBroadcasterReady = false;
  String _statusMessage = "Initializing Agora...";

  // Services
  final MediaPushService _mediaPushService = MediaPushService();

  // Video Player for Audience (HLS)
  VideoPlayerController? _videoController;

  // Animations
  late AnimationController _heartAnimController;

  @override
  void initState() {
    super.initState();
    // Keep screen on
    WakelockPlus.enable();

    // Mute feed audio when entering live stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isFeedAudioEnabledProvider.notifier).state = false;
    });

    if (widget.isBroadcaster) {
      _initBroadcaster();
    } else {
      _initPlayer();
    }

    // Initialize RTM Service
    // Using a random int for UID (string format) since we don't have real auth
    _liveService.initialize(
      uid: (1000 + DateTime.now().millisecondsSinceEpoch % 10000).toString(),
      channelId: widget.channelId,
    );

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Stream Listeners
    _liveService.messageStream.listen((msg) {
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });

    _liveService.reactionStream.listen((_) {
      if (mounted) _showHeartAnimation();
    });

    _liveService.giftStream.listen((gift) {
      if (mounted) _showGiftAnimation(gift);
    });
  }

  Future<void> _initBroadcaster() async {
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(
        appId: ApiConstants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        audioScenario: AudioScenarioType.audioScenarioDefault,
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
            "Agora: Joined Channel ${connection.channelId} uid=${connection.localUid}",
          );
          setState(() {
            _statusMessage = "Joined. Triggering Media Push API...";
          });
          // Call REST API instead of SDK Method
          if (connection.localUid != null) {
            _triggerMediaPushApi(connection.localUid!);
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint("Remote user joined: $remoteUid");
        },
        onRtmpStreamingStateChanged:
            (
              String url,
              RtmpStreamPublishState state,
              RtmpStreamPublishReason errCode,
            ) {
              // Providing visibility on SDK state, though REST API governs it now
              debugPrint("SDK State: $state, $errCode");
            },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("Agora Error: $err $msg");
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    // Set Video Quality to HD (720p) - Landscape Input + Portrait Mode = Standard Vertical
    await _engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        // Vertical HD Resolution
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 24,
        bitrate: 3000,
        orientationMode: OrientationMode.orientationModeAdaptive,
      ),
    );
    await _engine.enableAudio();

    await _engine.startPreview();
    setState(() => _isBroadcasterReady = true);

    await _engine.setCameraCapturerConfiguration(
      const CameraCapturerConfiguration(
        cameraDirection: CameraDirection.cameraRear,
        format: VideoFormat(width: 1280, height: 720, fps: 24),
      ),
    );

    await _engine.joinChannel(
      token: ApiConstants.agoraTempToken,
      channelId: ApiConstants.fixedTestChannelId,
      uid: 1000,
      options: const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    // Prioritize Clear Video over Smooth Frame Rate
    await _engine.setParameters(
      "{\"che.video.enableLowBitRateStream\": false}",
    );
  }

  Future<void> _triggerMediaPushApi(int uid) async {
    try {
      await _mediaPushService.startMediaPush(
        channelId: ApiConstants.fixedTestChannelId,
        uid: uid,
        rtmpUrl: ApiConstants.rtmpUrl,
      );
      if (mounted) {
        setState(() => _statusMessage = "LIVE! (API Request Sent)");
      }
    } catch (e) {
      debugPrint("API Failure: $e");
      if (mounted) {
        setState(() => _statusMessage = "API Failed: $e");
      }
    }
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(ApiConstants.hlsPlayUrl),
      );
      await _videoController!.initialize();
      await _videoController!.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error init player: $e");
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _heartAnimController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    _videoController?.dispose();

    if (widget.isBroadcaster) {
      // Async method but we can't await in dispose.
      // Fire and forget, or call a separate shutdown method before popping screen.
      // For safety, we just call it.
      _mediaPushService.stopMediaPush(
        channelId: ApiConstants.fixedTestChannelId,
      );

      _engine.stopRtmpStream(ApiConstants.rtmpUrl);
      _engine.stopDirectCdnStreaming(); // Stop both just in case
      _engine.leaveChannel();
      _engine.release();
    }

    ref.read(isFeedAudioEnabledProvider.notifier).state = true;
    super.dispose();
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
    _heartAnimController.forward(from: 0).then((_) {
      _heartAnimController.reset();
    });
  }

  void _showGiftAnimation(LiveGift gift) {
    // Handled by GiftOverlay stream listener
  }

  void _sendMessage() {
    if (_commentController.text.trim().isEmpty) return;
    final msg = LiveMessage(username: 'Me', message: _commentController.text);
    setState(() => _messages.add(msg));
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

          // Status Overlay
          if (widget.isBroadcaster)
            Positioned(
              top: 100,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Close Button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                if (widget.isBroadcaster) {
                  _showEndLiveDialog(context);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),

          // LIVE Tag
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

          // Floating Hearts
          FloatingHeartsOverlay(
            triggerStream: _liveService.reactionStream.map((_) {}),
          ),

          // Gift Overlay
          GiftOverlay(giftStream: _liveService.giftStream),

          // Bottom Controls
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
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Messages
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
                  // Input & Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Say something...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
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
                      IconButton(
                        icon: const Icon(
                          Icons.favorite,
                          color: AppColors.neonPink,
                        ),
                        onPressed: _sendHeart,
                      ),
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
    if (_isBroadcasterReady) {
      return SizedBox.expand(
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeHidden, // Fill screen (crop)
              mirrorMode: VideoMirrorModeType
                  .videoMirrorModeEnabled, // Mirror local preview
            ),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _renderAudienceVideo() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover, // Fill screen (crop)
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
  }

  void _showEndLiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("End Live Stream?"),
        content: const Text("Are you sure you want to end your live?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("End", style: TextStyle(color: Colors.red)),
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
                          ? AppColors.neonPink.withAlpha(25)
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPink,
                ),
                onPressed: _selectedIndex == -1
                    ? null
                    : () {
                        final gift = _gifts[_selectedIndex];
                        if (_balance >= (gift['value'] as int)) {
                          setState(() => _balance -= gift['value'] as int);
                          widget.onGiftSent(gift['name'], gift['value']);
                        } else {
                          // Show Recharge Dialog
                          _showRechargeDialog(context);
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

  void _showRechargeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
            ),
            onPressed: () {
              // Mock recharge
              setState(() => _balance += 100);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Recharged 100 Coins!"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              "Buy 100 Coins",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
