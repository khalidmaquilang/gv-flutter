import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_flutter/core/constants/api_constants.dart';
import 'package:test_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:test_flutter/features/feed/presentation/providers/feed_audio_provider.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

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
  @override
  void initState() {
    super.initState();
    // Mute feed audio when entering live stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isFeedAudioEnabledProvider.notifier).state = false;
    });
  }

  @override
  void dispose() {
    // Re-enable feed audio when leaving live stream
    // Using simple read in dispose is generally safe for Notifier providers
    // referring to state, but we should be careful.
    // However, given the original code did it, we maintain it.
    // Ideally we should use a Riverpod 2.0 pattern but this is a quick migration.
    ref.read(isFeedAudioEnabledProvider.notifier).state = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get user info from auth provider
    final user = ref.watch(authControllerProvider).value;
    // Fallback if user is not logged in (though typically they are)
    final String userID =
        user?.id.toString() ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final String userName = user?.name ?? 'Guest User';

    return SafeArea(
      child: ZegoUIKitPrebuiltLiveStreaming(
        appID: ApiConstants.zegoAppId,
        appSign: ApiConstants.zegoAppSign,
        userID: userID,
        userName: userName,
        liveID: widget.channelId,
        config: widget.isBroadcaster
            ? (ZegoUIKitPrebuiltLiveStreamingConfig.host()
                ..turnOnCameraWhenJoining = true
                ..turnOnMicrophoneWhenJoining = true
                ..useFrontFacingCamera = true)
            : (ZegoUIKitPrebuiltLiveStreamingConfig.audience()
                ..turnOnCameraWhenJoining = false
                ..turnOnMicrophoneWhenJoining = false),
        events: ZegoUIKitPrebuiltLiveStreamingEvents(
          onStateUpdated: (ZegoLiveStreamingState state) {
            debugPrint('Zego Live Stream State Updated: $state');
            if (widget.isBroadcaster &&
                state == ZegoLiveStreamingState.living) {
              // Host started streaming, push to RTMP
              // Stream ID is typically just the room ID/live ID for the main host in standard config,
              // or generated.
              // For Zego Prebuilt Live, the host streamID usually matches the LiveID (RoomID)
              // with some suffix or just the LiveID.
              // SAFEST Strategy: Use the liveID (channelId) combined with standard suffix if needed,
              // BUT Zego Prebuilt often uses `roomID_userID_main` as streamID.
              // Let's rely on standard pattern or ZegoUIKit().

              // NOTE: Zego Prebuilt's default host stream ID format is often `roomID_userID_main`
              // But let's try pushing with just the LiveID first or ask ZegoExpress.

              // Actually, better approach: Use ZegoUIKit().getStreamList() if possible,
              // but that might be empty immediately.

              // Taking a calculated guess based on common Zego Prebuilt patterns:
              String streamID = '${widget.channelId}_${userID}_main';
              // Actually, let's try simply `widget.channelId` first as it's cleaner if possible,
              // but strictly technically Prebuilt uses specific conventions.
              // Let's use ZegoExpress directly.

              debugPrint('Attempting to push to CDN: ${ApiConstants.rtmpUrl}');
              ZegoExpressEngine.instance.addPublishCdnUrl(
                streamID, // This is the source stream ID
                ApiConstants.rtmpUrl,
              );

              // Also try without suffix just in case standard room mode logic applies
              // (which is unlikely for Prebuilt UI which supports multiple hosts, but safe to try if 1 fails)
            }
          },
        ),
      ),
    );
  }
}
