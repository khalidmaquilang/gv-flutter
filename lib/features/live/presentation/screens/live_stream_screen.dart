import 'package:flutter/material.dart';
import 'dart:math' as math;
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
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

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
  // Audience Video
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  String? _localUserID;
  String? _localUserName;

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

    // HOST: Skip custom engine init - let UIKit manage it
    if (widget.isBroadcaster) {
      return; // Exit early - UIKit handles everything
    }

    // AUDIENCE: Initialize custom engine for playback
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

    // Initialize ZIM
    await _initializeZIM(zegoUser, widget.channelId);

    // Mute RTC Audio to prevent double audio (CDN + RTC)
    if (!widget.isBroadcaster) {
      await ZegoExpressEngine.instance.muteAllPlayStreamAudio(true);
    }

    // Audience Logic: Start the HLS player
    _startAudienceMode();
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

    ZegoExpressEngine.onRoomUserUpdate =
        (String roomID, ZegoUpdateType updateType, List<ZegoUser> userList) {
          // Manual notifications removed as UIKit handles them
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
                  final result = await ZegoExpressEngine.instance
                      .addPublishCdnUrl(streamID, ApiConstants.rtmpUrl);
                  if (result.errorCode == 0) {
                    debugPrint("RTMP Push Success: ${ApiConstants.rtmpUrl}");
                  } else {
                    debugPrint("RTMP Push Failed: Error ${result.errorCode}");
                  }
                } catch (e) {
                  debugPrint("RTMP Push Exception: $e");
                }
              });
            }
          } else if (state == ZegoPublisherState.NoPublish && errorCode != 0) {
            if (mounted) {
              debugPrint("Publish Error: $errorCode");
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
        };

    try {
      await ZIM.getInstance()!.login(
        user.userID,
        ZIMLoginConfig()..userName = user.userName,
      );

      await ZIM.getInstance()!.joinRoom(roomID);
    } catch (e) {
      debugPrint("ZIM Init Error: $e");
    }
  }

  // --- AUDIENCE LOGIC ---

  void _startAudienceMode() {
    // Enable WakeLock for audience
    WakelockPlus.enable();

    // Reset state immediately to prevent UI from trying to render a disposed/null controller
    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
        _videoController?.dispose();
        _videoController = null;
      });
    } else {
      _videoController?.dispose();
      _videoController = null;
    }

    // Slight delay to allow HLS segments to propagate after resume
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      final newController = VideoPlayerController.networkUrl(
        Uri.parse(ApiConstants.hlsPlayUrl),
      );

      _videoController = newController;

      newController
          .initialize()
          .then((_) {
            if (!mounted) {
              newController.dispose();
              return;
            }
            // Ensure the first frame is shown after the video is initialized
            if (_videoController == newController) {
              // Check if still the active controller
              setState(() {
                _isVideoInitialized = true;
              });
              newController.play();
            }
          })
          .catchError((e) {
            debugPrint("Video Player Init Error: $e");
            if (mounted && _videoController == newController) {
              // Optionally handle error state in UI
            }
          });
    });
  }

  void _stopPlaying() {
    _videoController?.pause();
    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();

    // Only destroy engine for audience (hosts use UIKit which manages its own lifecycle)
    if (!widget.isBroadcaster) {
      _destroy();
    }

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
    // Disable system back swipe gesture
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Optionally show exit confirmation here if needed,
        // but typically Zego UI handles exit button.
      },
      child: widget.isBroadcaster
          ? _buildHostUIKit(context)
          : _buildAudienceUIKit(context),
    );
  }

  Widget _buildAudienceUIKit(BuildContext context) {
    // Capture controller locally to ensure null safety during build
    final activeController = _videoController;
    final isReady =
        _isVideoInitialized &&
        activeController != null &&
        activeController.value.isInitialized;

    return ZegoUIKitPrebuiltLiveStreaming(
      appID: ApiConstants.zegoAppId,
      appSign: ApiConstants.zegoAppSign,
      userID: _localUserID ?? 'guest',
      userName: _localUserName ?? 'Guest',
      liveID: widget.channelId,
      config:
          ZegoUIKitPrebuiltLiveStreamingConfig.audience(
              plugins: [ZegoUIKitSignalingPlugin()],
            )
            // Neon theme customization matching Host
            ..topMenuBar.backgroundColor = Colors.transparent
            ..bottomMenuBar.backgroundColor = Colors.transparent
            // Remove co-host button by restricting visible buttons
            // Correct property name is 'audienceButtons' (or hostButtons)
            ..bottomMenuBar.audienceButtons = [
              ZegoLiveStreamingMenuBarButtonName.chatButton,
            ]
            ..inRoomMessage.backgroundColor = AppColors.deepVoid.withValues(
              alpha: 0.7,
            )
            ..inRoomMessage.nameTextStyle = TextStyle(
              color: AppColors.neonCyan,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            )
            ..inRoomMessage.messageTextStyle = TextStyle(
              color: Colors.white,
              fontSize: 14,
            )
            // User join notifications
            ..inRoomMessage.notifyUserJoin = true
            ..inRoomMessage.notifyUserLeave = false
            ..innerText.userEnter = 'joined'
            // INJECT HLS PLAYER DIRECTLY INTO ZEGO VIEW
            // This replaces the RTC Video View with our Custom HLS VideoPlayer
            ..audioVideoView
                .containerBuilder = (context, size, user, extraInfo) {
              // Only replace for the host/broadcaster or main stream
              // For now, replacing for ANY user in the view (typically just the host)
              return isReady
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: activeController.value.aspectRatio,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi), // Mirror fix
                          child: VideoPlayer(activeController),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.deepVoid,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.neonCyan,
                        ),
                      ),
                    );
            },
    );
  }

  Widget _buildHostUIKit(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          ZegoUIKitPrebuiltLiveStreaming(
            appID: ApiConstants.zegoAppId,
            appSign: ApiConstants.zegoAppSign,
            userID: _localUserID ?? 'unknown',
            userName: _localUserName ?? 'Unknown User',
            liveID: widget.channelId,
            events: ZegoUIKitPrebuiltLiveStreamingEvents(
              onLeaveConfirmation:
                  (
                    ZegoLiveStreamingLeaveConfirmationEvent event,
                    Future<bool> Function() defaultAction,
                  ) async {
                    return await showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext dialogContext) {
                            return AlertDialog(
                              backgroundColor: AppColors.deepVoid,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: AppColors.neonPink,
                                  width: 2,
                                ),
                              ),
                              title: Text(
                                "End Live Stream?",
                                style: TextStyle(
                                  color: AppColors.neonCyan,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                              content: Text(
                                "Are you sure you want to end your live stream?",
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.neonPink,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: Text(
                                    "End Stream",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;
                  },
            ),
            config:
                ZegoUIKitPrebuiltLiveStreamingConfig.host(
                    plugins: [ZegoUIKitSignalingPlugin()],
                  )
                  // Camera settings
                  ..audioVideoView.useVideoViewAspectFill = true
                  ..turnOnCameraWhenJoining = true
                  ..turnOnMicrophoneWhenJoining = true
                  ..useFrontFacingCamera = true
                  // Neon theme customization
                  ..topMenuBar.backgroundColor = Colors.transparent
                  ..bottomMenuBar.backgroundColor = Colors.transparent
                  // Chat message styling (neon theme)
                  ..inRoomMessage.backgroundColor = AppColors.deepVoid
                      .withValues(alpha: 0.7)
                  ..inRoomMessage.nameTextStyle = TextStyle(
                    color: AppColors.neonCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  )
                  ..inRoomMessage.messageTextStyle = TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  )
                  // User join/leave notifications
                  ..inRoomMessage.notifyUserJoin = true
                  ..inRoomMessage.notifyUserLeave = false
                  ..innerText.userEnter = 'joined'
                  ..bottomMenuBar.showInRoomMessageButton =
                      false, // Hide message button
          ),
          // Custom Quality Indicator Overlay (Added via Stack)
          Positioned(
            top: 10,
            right: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.neonCyan),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi, color: AppColors.neonCyan, size: 12),
                  const SizedBox(width: 4),
                  const Text(
                    "Good", // Placeholder
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
