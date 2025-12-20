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
  int? _playViewID;
  Widget? _hostView;
  Widget? _audienceView;
  bool _isEngineActive = false;
  String? _localUserID;
  String? _localUserName;

  // Host State
  bool _isLive = false; // False = Preview Mode, True = Streaming Mode
  bool _isUsingFrontCamera = true;

  // Room State
  int _viewerCount = 0;

  // ZIM State
  final List<ZIMTextMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();

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
      // Create Audience View Placeholder
      _audienceView = await ZegoExpressEngine.instance.createCanvasView((
        viewID,
      ) {
        _playViewID = viewID;
      });
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
              _playHLSStream();
            }
          } else if (updateType == ZegoUpdateType.Delete) {
            if (!widget.isBroadcaster) {
              _stopPlaying(); // Host stopped
            }
          }
        };

    // Viewer Count Update
    ZegoExpressEngine.onRoomOnlineUserCountUpdate = (String roomID, int count) {
      setState(() {
        _viewerCount = count;
      });
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
              debugPrint("Starting RTMP Push to: ${ApiConstants.rtmpUrl}");
              // We need to mark this lambda as async to await result
              Future(() async {
                try {
                  final result = await ZegoExpressEngine.instance
                      .addPublishCdnUrl(streamID, ApiConstants.rtmpUrl);
                  if (mounted) {
                    if (result.errorCode == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("RTMP Push SUCCESS"),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "RTMP Push FAILED: ${result.errorCode}",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
    ZIM.create(
      ZIMAppConfig()
        ..appID = ApiConstants.zegoAppId
        ..appSign = ApiConstants.zegoAppSign,
    );

    try {
      await ZIM.getInstance()!.login(
        user.userID,
        ZIMLoginConfig()..userName = user.userName,
      );
    } catch (e) {
      debugPrint("ZIM Login Error: $e");
    }

    // Event Handler
    ZIMEventHandler
        .onRoomMessageReceived = (zim, messageList, info, fromRoomID) {
      if (fromRoomID != widget.channelId) return;

      for (var msg in messageList) {
        if (msg is ZIMTextMessage) {
          if (mounted) {
            setState(() {
              _messages.insert(0, msg);
            });
          }
        } else if (msg is ZIMCommandMessage) {
          final data = String.fromCharCodes(msg.message);
          if (data.startsWith("GIFT:")) {
            final giftName = data.split(":")[1];
            debugPrint("Received Gift: $giftName");
            // Show visual effect
            if (mounted) {
              // Using a simple toast/snackbar for now, can be upgraded to overlay
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Received Gift: $giftName"),
                  backgroundColor: AppColors.neonPink,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }
        }
      }
    };

    try {
      await ZIM.getInstance()!.joinRoom(roomID);
    } catch (e) {
      debugPrint("ZIM Join Error: $e");
    }
  }

  Future<void> _sendChatMessage() async {
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
    final command = ZIMCommandMessage(
      message: Uint8List.fromList("GIFT:$giftName".codeUnits),
    );
    try {
      await ZIM.getInstance()?.sendMessage(
        command,
        widget.channelId,
        ZIMConversationType.room,
        ZIMMessageSendConfig(),
      );
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
    // Audience waits for stream update to call _playHLSStream
  }

  Future<void> _playHLSStream() async {
    // Play from constant HLS URL
    // Use Zego Player with Resource Mode CDN
    ZegoCDNConfig cdnConfig = ZegoCDNConfig(ApiConstants.hlsPlayUrl);

    // IMPORTANT: When using CdnOnly, streamID parameter in startPlayingStream
    // is typically mapped to the CDN URL via config, or we pass the URL as streamID if supported.
    // Zego Express Docs says: for CDN, pass streamID, and config with URL.
    // But if it's a direct URL (no Zego Stream ID mapping), we might need to use generic stream ID.
    // Let's us the channelId as base.

    ZegoPlayerConfig config = ZegoPlayerConfig(ZegoStreamResourceMode.OnlyCDN)
      ..cdnConfig = cdnConfig;

    String streamID =
        '${widget.channelId}_host_main'; // Construct assumed ID or arbitrary

    if (_playViewID != null) {
      await ZegoExpressEngine.instance.startPlayingStream(
        streamID,
        config: config,
        canvas: ZegoCanvas.view(_playViewID!),
      );
    }
    setState(() {});
  }

  void _stopPlaying() {
    // ZegoExpressEngine.instance.stopPlayingStream(streamID);
    setState(() {});
  }

  @override
  void dispose() {
    _destroy();
    WakelockPlus.disable();
    ref.read(isFeedAudioEnabledProvider.notifier).state = true;
    super.dispose();
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
                        onTap: () => Navigator.of(context).pop(),
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
                              child: Text(
                                msg.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  shadows: [
                                    Shadow(blurRadius: 2, color: Colors.black),
                                  ],
                                ),
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

                          // Hide Buttons for Host
                          if (!widget.isBroadcaster) ...[
                            const SizedBox(width: 10),
                            _buildNeonActionButton(
                              Icons.card_giftcard,
                              AppColors.neonPink,
                              () => _sendGift("HEART"),
                            ),
                            const SizedBox(width: 10),
                            _buildNeonActionButton(
                              Icons.favorite,
                              AppColors.neonCyan,
                              () => _sendGift("LIKE"),
                            ),
                          ],

                          const SizedBox(width: 10),
                          _buildNeonActionButton(
                            Icons.share,
                            Colors.white,
                            () {},
                          ),
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

  Widget _buildHostView() {
    if (_hostView != null) {
      return Stack(
        children: [
          _hostView!,
          // Debug Overlay
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Preview ID: $_previewViewID",
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                  Text(
                    "Engine Active: $_isEngineActive",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    "Is Live: $_isLive",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () async {
                      await ZegoExpressEngine.instance.stopPreview();
                      await ZegoExpressEngine.instance.enableCamera(false);
                      await Future.delayed(const Duration(milliseconds: 500));
                      await ZegoExpressEngine.instance.enableCamera(true);
                      await ZegoExpressEngine.instance.startPreview(
                        canvas: ZegoCanvas.view(_previewViewID!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Restarted Preview")),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: Colors.blue,
                      child: const Text(
                        "Restart Camera",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () async {
                      await ZegoExpressEngine.instance.useFrontCamera(
                        !_isUsingFrontCamera,
                      );
                      setState(() {
                        _isUsingFrontCamera = !_isUsingFrontCamera;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Switched to ${_isUsingFrontCamera ? 'Front' : 'Back'} Camera",
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: Colors.orange,
                      child: const Text(
                        "Switch Camera",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: AppColors.neonPink),
    );
  }

  Widget _buildAudienceView() {
    if (_audienceView != null) return _audienceView!;
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.neonPink),
          SizedBox(height: 20),
          Text(
            "Waiting for Host to start...",
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
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
}
