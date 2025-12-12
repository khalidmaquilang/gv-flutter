import 'dart:async';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/live_interaction_model.dart';
import '../models/live_stream_model.dart';
import '../../../auth/data/models/user_model.dart';

class LiveService {
  RtcEngine? _engine;
  final String appId = "YOUR_AGORA_APP_ID"; // Todo: Move to config

  // Mock Streams
  final _messageController = StreamController<LiveMessage>.broadcast();
  final _reactionController = StreamController<LiveReaction>.broadcast();
  final _giftController = StreamController<LiveGift>.broadcast();
  Timer? _simulationTimer;

  Stream<LiveMessage> get messageStream => _messageController.stream;
  Stream<LiveReaction> get reactionStream => _reactionController.stream;
  Stream<LiveGift> get giftStream => _giftController.stream;

  Future<void> initialize({
    required void Function(RtcEngineEventHandler) onEvent,
  }) async {
    await [Permission.microphone, Permission.camera].request();

    // Start Simulation
    _startSimulation();

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

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final random = Random();

      // Random Message
      if (random.nextDouble() > 0.5) {
        final users = ['User A', 'User B', 'User C', 'Fan 1', 'Fan 2'];
        final msgs = [
          'Cool!',
          'Hello',
          'Wow',
          'Nice stream',
          'Hello from generic location',
        ];
        _messageController.add(
          LiveMessage(
            username: users[random.nextInt(users.length)],
            message: msgs[random.nextInt(msgs.length)],
          ),
        );
      }

      // Random Reaction
      if (random.nextDouble() > 0.3) {
        _reactionController.add(
          LiveReaction(type: LiveReactionType.heart, username: 'Anonymous'),
        );
      }

      // Random Gift (Rare)
      if (random.nextDouble() > 0.9) {
        _giftController.add(
          LiveGift(username: "Super Fan", giftName: "Rose", value: 10),
        );
      }
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
  }

  // User Actions
  void sendComment(String text) {
    _messageController.add(LiveMessage(username: "Me", message: text));
  }

  void sendReaction() {
    _reactionController.add(
      LiveReaction(type: LiveReactionType.heart, username: "Me"),
    );
  }

  void sendGift() {
    _giftController.add(
      LiveGift(username: "Me", giftName: "Galaxy", value: 100),
    );
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
    stopSimulation();
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
    }
  }

  Future<List<LiveStream>> getActiveStreams() async {
    // Mock Delay
    await Future.delayed(const Duration(milliseconds: 500));

    return List.generate(10, (index) {
      return LiveStream(
        channelId: "channel_$index",
        user: User(
          id: index,
          name: "Live User $index",
          email: "live$index@test.com",
          avatar: "https://via.placeholder.com/50",
        ),
        thumbnailUrl: "https://via.placeholder.com/300x400",
        viewersCount: Random().nextInt(5000) + 100,
        title: "Live Stream #$index - Join now!",
      );
    });
  }
}
