import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_flutter/core/constants/api_constants.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:test_flutter/features/feed/presentation/providers/feed_audio_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:zego_zim/zego_zim.dart';
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

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  // Zego State
  int? _previewViewID;
  Widget? _hostView;
  bool _isEngineActive = false;

  // Audience Video
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  String? _localUserID;
  String? _localUserName;

  // Host State
  bool _isLive = false; // False = Preview Mode, True = Streaming Mode
  bool _isZIMConnected = false;
  bool _isStreamEnded = false;

  // Room State
  int _viewerCount = 0;

  // ZIM State
  final List<ZIMTextMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();

  final List<GiftItem> _gifts = [
    GiftItem(id: 'rose', name: 'Rose', icon: '🌹', cost: 1),
    GiftItem(id: 'heart', name: 'Heart', icon: '❤️', cost: 5),
    GiftItem(id: 'party', name: 'Party', icon: '🎉', cost: 10),
    GiftItem(id: 'diamond', name: 'Diamond', icon: '💎', cost: 50),
    GiftItem(id: 'rocket', name: 'Rocket', icon: '🚀', cost: 100),
  ];

  @override
  void initState() {
    super.initState();
    _handleAudio();
    _initializeEngine();
  }

  void _handleAudio() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isFeedAudioEnabledProvider.notifier).state = false;
    });
  }

  Future<void> _initializeEngine() async {
    final user = ref.read(authControllerProvider).value;
    _localUserID =
        user?.id.toString() ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _localUserName = user?.name ?? 'Guest User';

    await [Permission.camera, Permission.microphone].request();

    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(
        ApiConstants.zegoAppId,
        ZegoScenario.Broadcast,
        appSign: ApiConstants.zegoAppSign,
      ),
    );

    // Disable Hardware Decoding (Fixes Black Screen on Emulators viewing H264)
    await ZegoExpressEngine.instance.enableHardwareDecoder(false);

    // Force 360p for stable RTMP/Emulator performance
    ZegoVideoConfig videoConfig = ZegoVideoConfig.preset(
      ZegoVideoConfigPreset.Preset360P,
    );
    await ZegoExpressEngine.instance.setVideoConfig(videoConfig);

    _setZegoEventHandlers();

    final ZegoUser zegoUser = ZegoUser(_localUserID!, _localUserName!);
    final ZegoRoomConfig roomConfig = ZegoRoomConfig.defaultConfig()
      ..isUserStatusNotify = true;

    await ZegoExpressEngine.instance.loginRoom(
      widget.channelId,
      zegoUser,
      config: roomConfig,
    );

    setState(() {
      _isEngineActive = true;
    });

    // Initialize ZIM
    await _initializeZIM(zegoUser, widget.channelId);

    if (widget.isBroadcaster) {
      // Host Logic: Create View
      _hostView = await ZegoExpressEngine.instance.createCanvasView((viewID) {
        _previewViewID = viewID;
        // Do NOT start preview here. We control it in _startPreview.
      });
      // Set to preview mode
      await _startPreview();
    } else {
      // Audience Logic: Just start the player (no Zego Canvas needed)
      _startAudienceMode();
    }

    setState(() {
      _isEngineActive = true;
    });
  }

  void _setZegoEventHandlers() {
    ZegoExpressEngine.onRoomStreamUpdate =
        (
          String roomID,
          ZegoUpdateType updateType,
          List<ZegoStream> streamList,
          Map<String, dynamic> extendedData,
        ) {
          if (updateType == ZegoUpdateType.Add) {
            if (!widget.isBroadcaster) {
              // Audience: Play HLS when stream is added
              _startAudienceMode();
            }
          } else if (updateType == ZegoUpdateType.Delete) {
            if (!widget.isBroadcaster) {
              _stopPlaying(); // Host stopped
            }
          }
        };

    // Viewer Count & User Update
    ZegoExpressEngine.onRoomOnlineUserCountUpdate = (String roomID, int count) {
      setState(() {
        _viewerCount = count;
      });
    };

    ZegoExpressEngine.onRoomUserUpdate =
        (String roomID, ZegoUpdateType updateType, List<ZegoUser> userList) {
          if (updateType == ZegoUpdateType.Add) {
            for (var user in userList) {
              _addSystemMessage("${user.userName} joined the stream 🚀");
            }
          } else {
            for (var _ in userList) {
              // _addSystemMessage("${user.userName} left the stream 👋"); // Disabled by user
            }
          }
        };

    ZegoExpressEngine.onPublisherStateUpdate =
        (
          String streamID,
          ZegoPublisherState state,
          int errorCode,
          Map<String, dynamic> extendedData,
        ) {
          if (state == ZegoPublisherState.Publishing) {
            if (widget.isBroadcaster) {
              // We need to mark this lambda as async to await result
              Future(() async {
                try {
                  await ZegoExpressEngine.instance.addPublishCdnUrl(
                    streamID,
                    ApiConstants.rtmpUrl,
                  ); // result ignored
                } catch (e) {
                  debugPrint("RTMP Push Error: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("RTMP Push Exception: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              });
            }
          } else if (state == ZegoPublisherState.NoPublish && errorCode != 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Publish Error: $errorCode"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        };
  }

  Future<void> _initializeZIM(ZegoUser user, String roomID) async {
    // Ensure any previous instance is destroyed before creating a new one
    ZIM.getInstance()?.destroy();

    ZIM.create(
      ZIMAppConfig()
        ..appID = ApiConstants.zegoAppId
        ..appSign = ApiConstants.zegoAppSign,
    );

    // Event Handler (Must be set before login)
    ZIMEventHandler.onConnectionStateChanged =
        (zim, state, event, extendedData) {
          debugPrint("ZIM Connection State: $state, Event: $event");
          if (mounted) {
            setState(() {
              _isZIMConnected = (state == ZIMConnectionState.connected);
            });
          }
        };

    ZIMEventHandler.onRoomMessageReceived =
        (zim, messageList, info, fromRoomID) {
          if (fromRoomID != widget.channelId) return;

          for (var msg in messageList) {
            if (msg is ZIMTextMessage) {
              if (mounted) {
                setState(() {
                  _messages.insert(0, msg);
                });
              }
            } else if (msg is ZIMCommandMessage) {
              // ... (Same Command Logic as before) ...
              final data = String.fromCharCodes(msg.message);
              if (data.startsWith("GIFT:")) {
                final parts = data.split(":");
                if (parts.length > 1) {
                  final giftId = parts[1];
                  GiftItem? gift;
                  try {
                    gift = _gifts.firstWhere((g) => g.id == giftId);
                  } catch (e) {
                    gift = _gifts[1];
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Text("Received: ${gift.name} ${gift.icon}"),
                            const SizedBox(width: 10),
                            const Icon(Icons.celebration, color: Colors.white),
                          ],
                        ),
                        backgroundColor: AppColors.neonPink,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            }
          }
        };

    ZIMEventHandler.onRoomMemberJoined = (zim, memberList, roomID) {
      // Using ZegoEngine for this
    };
    ZIMEventHandler.onRoomMemberLeft = (zim, memberList, roomID) {
      // Using ZegoEngine for this
    };

    try {
      debugPrint("ZIM Logging in as ${user.userID}...");
      await ZIM.getInstance()!.login(
        user.userID,
        ZIMLoginConfig()..userName = user.userName,
      );
      debugPrint("ZIM Login Success!");

      debugPrint("ZIM Joining Room $roomID...");
      await ZIM.getInstance()!.joinRoom(roomID);
      debugPrint("ZIM Join Room Success!");
    } catch (e) {
      debugPrint("ZIM Init Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Chat Init Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendChatMessage() async {
    // ... existing chat logic ...
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final myMsg = ZIMTextMessage(message: text);
    myMsg.senderUserID = _localUserID!;

    setState(() {
      _messages.insert(0, myMsg);
      _chatController.clear();
    });

    try {
      await ZIM.getInstance()?.sendMessage(
        myMsg,
        widget.channelId,
        ZIMConversationType.room,
        ZIMMessageSendConfig(),
      );
    } catch (e) {
      debugPrint("Send Error: $e");
    }
  }

  Future<void> _sendGift(String giftName) async {
    if (!_isZIMConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Not connected to Chat yet. Please wait."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    debugPrint(
      "Attempting to send gift: $giftName into room ${widget.channelId}",
    );
    final command = ZIMCommandMessage(
      message: Uint8List.fromList("GIFT:$giftName".codeUnits),
    );
    try {
      final result = await ZIM
          .getInstance()
          ?.sendMessage(
            command,
            widget.channelId,
            ZIMConversationType.room,
            ZIMMessageSendConfig(),
          )
          .then((value) {
            debugPrint("Gift Sent Successfully: ${value.message.messageID}");

            // Optimistic UI Update for Sender
            final gift = _gifts.firstWhere(
              (g) => g.id == giftName,
              orElse: () => _gifts[1],
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("You sent ${gift.icon} ${gift.name}!"),
                  backgroundColor: AppColors.neonCyan,
                ),
              );
            }
          });
    } catch (e) {
      debugPrint("Gift Send Error: $e");
    }
  }

  // --- HOST LOGIC ---

  Future<void> _startPreview() async {
    // Enable WakeLock to keep screen on
    await WakelockPlus.enable();

    // Ensure camera/mic are enabled (Critical for Emulator/Black Screen)
    await ZegoExpressEngine.instance.enableCamera(true);
    await ZegoExpressEngine.instance.muteMicrophone(false);

    // Just enable camera/preview view
    await ZegoExpressEngine.instance.useFrontCamera(true);

    // If previewViewID is properly set, ensure preview is started.
    // This covers cases where the first startPreview call in createView might have missed due to race conditions.
    if (_previewViewID != null) {
      await ZegoExpressEngine.instance.startPreview(
        canvas: ZegoCanvas.view(_previewViewID!),
      );
    }

    setState(() {
      _isLive = false; // Ready to preview
    });
  }

  Future<void> _startPublishing() async {
    String streamID = '${widget.channelId}_${_localUserID}_main';
    await ZegoExpressEngine.instance.startPublishingStream(streamID);
    setState(() {
      _isLive = true;
    });
  }

  // --- AUDIENCE LOGIC ---

  void _startAudienceMode() {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(ApiConstants.hlsPlayUrl))
          ..initialize().then((_) {
            // Ensure the first frame is shown after the video is initialized
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController!.play();
          });
  }

  /*
  Future<void> _playHLSStream() async {
     // Deprecated: Using VideoPlayerController instead
  }
  */

  void _stopPlaying() {
    _videoController?.pause();
    if (mounted) {
      setState(() {
        _isStreamEnded = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _destroy();
    WakelockPlus.disable();
    ref.read(isFeedAudioEnabledProvider.notifier).state = true;
    super.dispose();
  }

  // ... (Keep _destroy)

  // ... (Keep build)

  // ... (Keep _buildHostView)

  Widget _buildAudienceView() {
    if (_isStreamEnded) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.neonPink),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white, size: 50),
              const SizedBox(height: 10),
              const Text(
                "Live Stream Ended",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 20),
              _buildNeonActionButton(Icons.exit_to_app, AppColors.neonPink, () {
                Navigator.pop(context);
              }),
            ],
          ),
        ),
      );
    }

    if (_isVideoInitialized && _videoController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.neonPink),
          SizedBox(height: 20),
          Text(
            "Connecting to Live Stream...",
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _destroy() async {
    await ZegoExpressEngine.instance.logoutRoom(widget.channelId);
    await ZegoExpressEngine.destroyEngine();

    try {
      ZIM.getInstance()?.leaveRoom(widget.channelId);
      ZIM.getInstance()?.logout();
      ZIM.getInstance()?.destroy();
    } catch (e) {
      debugPrint("ZIM Destroy Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEngineActive) {
      return const Scaffold(
        backgroundColor: AppColors.deepVoid,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.neonPink),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.isBroadcaster
                ? _buildHostView()
                : _buildAudienceView(),
          ),

          // HOST PREVIEW OVERLAY
          if (widget.isBroadcaster && !_isLive)
            Container(
              color: Colors.black.withOpacity(0.4),
              padding: const EdgeInsets.only(bottom: 50),
              alignment: Alignment.bottomCenter, // Moved to bottom
              child: GestureDetector(
                onTap: _startPublishing,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.neonPink, AppColors.neonCyan],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPink.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Text(
                    "GO LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // User Info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.neonCyan.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: AppColors.neonPink,
                                  radius: 15,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.isBroadcaster ? "YOU (Host)" : "Host",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Viewer Count
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "$_viewerCount",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      GestureDetector(
                        onTap: () {
                          if (widget.isBroadcaster) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.black.withOpacity(0.9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(
                                    color: AppColors.neonPink,
                                  ),
                                ),
                                title: const Text(
                                  "End Live Stream?",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                                content: const Text(
                                  "Are you sure you want to end the live stream?",
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context); // Close dialog
                                      Navigator.pop(context); // Close screen
                                    },
                                    child: const Text(
                                      "End Stream",
                                      style: TextStyle(
                                        color: AppColors.neonPink,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          radius: 20,
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        height: 200,
                        alignment: Alignment.bottomLeft,
                        child: ListView.builder(
                          reverse: true,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg.senderUserID == _localUserID;
                            return Container(
                              margin: const EdgeInsets.only(
                                bottom: 8,
                                right: 40,
                              ),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.neonPink.withOpacity(0.15)
                                    : Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isMe
                                      ? AppColors.neonPink.withOpacity(0.4)
                                      : AppColors.neonCyan.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Sender Name
                                  if (!isMe && msg.senderUserID != "SYSTEM")
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        msg.senderUserID, // Ideally senderUserName if available
                                        style: TextStyle(
                                          color: AppColors.neonCyan.withOpacity(
                                            0.8,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  // Message Content
                                  Text(
                                    msg.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 2,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (!widget.isBroadcaster)
                            Expanded(
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: AppColors.neonCyan,
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: _chatController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Say something...",
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(
                                        Icons.send_rounded,
                                        color: AppColors.neonCyan,
                                      ),
                                      onPressed: _sendChatMessage,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendChatMessage(),
                                ),
                              ),
                            ),

                          if (widget.isBroadcaster) const Spacer(),

                          // Hide Buttons for Host (Host shouldn't gift themselves)
                          if (!widget.isBroadcaster) ...[
                            const SizedBox(width: 10),
                            _buildNeonActionButton(
                              Icons.card_giftcard,
                              AppColors.neonPink,
                              _showGiftPicker,
                            ),
                            const SizedBox(width: 10),
                            _buildNeonActionButton(
                              Icons.favorite,
                              AppColors.neonCyan,
                              () => _sendGift("heart"), // Quick Like
                            ),
                          ],

                          const SizedBox(width: 10),
                          _buildNeonActionButton(Icons.share, Colors.white, () {
                            // Share logic would go here
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGiftPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: const Border(top: BorderSide(color: AppColors.neonPink)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Send a Gift",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: _gifts.length,
                  itemBuilder: (context, index) {
                    final gift = _gifts[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _sendGift(gift.id);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.deepVoid,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.neonCyan.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              gift.icon,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              gift.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "${gift.cost} coins",
                              style: TextStyle(
                                color: AppColors.neonPink.withOpacity(0.8),
                                fontSize: 10,
                              ),
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
        );
      },
    );
  }

  Widget _buildHostView() {
    if (_hostView != null) {
      return Stack(children: [_hostView!]);
    }
    return const Center(
      child: CircularProgressIndicator(color: AppColors.neonPink),
    );
  }

  Widget _buildNeonActionButton(
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.5),
          border: Border.all(color: color),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _addSystemMessage(String text) {
    final sysMsg = ZIMTextMessage(message: text);
    sysMsg.senderUserID = "SYSTEM";
    if (mounted) {
      setState(() {
        _messages.insert(0, sysMsg);
      });
    }
  }
}

class GiftItem {
  final String id;
  final String name;
  final String icon;
  final int cost;

  GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.cost,
  });
}
