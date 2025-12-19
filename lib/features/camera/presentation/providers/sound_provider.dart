import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/api_provider.dart';
import '../../data/services/sound_service.dart';

final soundServiceProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SoundService(apiClient: apiClient);
});
