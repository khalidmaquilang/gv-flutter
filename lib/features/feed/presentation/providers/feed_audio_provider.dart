import 'package:flutter_riverpod/flutter_riverpod.dart';

// True = Feed audio should play (if on Feed tab)
// False = Feed audio forced mute (e.g. Recorder or Live Setup active)
final isFeedAudioEnabledProvider = StateProvider<bool>((ref) => true);

// Track which feed tab is active: 0 = Live, 1 = Following, 2 = For You
final activeFeedTabProvider = StateProvider<int>(
  (ref) => 2,
); // Start at "For You"
