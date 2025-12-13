import 'package:flutter_riverpod/flutter_riverpod.dart';

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// Use a timestamp or counter to signal a reset event
final feedTabResetProvider = StateProvider<int>((ref) => 0);
