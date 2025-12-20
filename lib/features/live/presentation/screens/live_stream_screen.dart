import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_flutter/core/constants/api_constants.dart';
import 'package:test_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:test_flutter/features/feed/presentation/providers/feed_audio_provider.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import 'package:zego_uikit/zego_uikit.dart';

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
      ),
    );
  }
}
