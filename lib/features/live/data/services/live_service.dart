import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveService {
  RtcEngine? _engine;
  final String appId = "YOUR_AGORA_APP_ID"; // Todo: Move to config

  Future<void> initialize({
    required void Function(RtcEngineEventHandler) onEvent,
  }) async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      const RtcEngineContext(
        appId: "YOUR_AGORA_APP_ID",
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          // onEvent...
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          // onEvent...
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              // onEvent...
            },
      ),
    );

    await _engine!.enableVideo();
    await _engine!.startPreview();
  }

  Future<void> joinChannel(
    String channelName,
    String token,
    bool isBroadcaster,
  ) async {
    if (_engine == null) return;
    await _engine!.setClientRole(
      role: isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
    }
  }
}
