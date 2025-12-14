import 'dart:async';
import 'dart:math';

import '../models/live_interaction_model.dart';
import '../models/live_stream_model.dart';
import '../../../auth/data/models/user_model.dart';

class LiveService {
  // Mock Streams
  final _messageController = StreamController<LiveMessage>.broadcast();
  final _reactionController = StreamController<LiveReaction>.broadcast();
  final _giftController = StreamController<LiveGift>.broadcast();
  Timer? _simulationTimer;

  Stream<LiveMessage> get messageStream => _messageController.stream;
  Stream<LiveReaction> get reactionStream => _reactionController.stream;
  Stream<LiveGift> get giftStream => _giftController.stream;

  // Constructor
  LiveService() {
    _startSimulation();
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

  void dispose() {
    _simulationTimer?.cancel();
    _messageController.close();
    _reactionController.close();
    _giftController.close();
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

  void sendGift(String name, int value) {
    _giftController.add(LiveGift(username: "Me", giftName: name, value: value));
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
          avatar: "https://dummyimage.com/50",
        ),
        thumbnailUrl: "https://dummyimage.com/300x400",
        viewersCount: Random().nextInt(5000) + 100,
        title: "Live Stream #$index - Join now!",
      );
    });
  }
}
