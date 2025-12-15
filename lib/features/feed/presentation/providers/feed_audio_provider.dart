import 'package:flutter_riverpod/flutter_riverpod.dart';

// True = Feed audio should play (if on Feed tab)
// False = Feed audio forced mute (e.g. Recorder or Live Setup active)
final isFeedAudioEnabledProvider = StateProvider<bool>((ref) => true);
