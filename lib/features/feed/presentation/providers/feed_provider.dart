import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/video_model.dart';
import '../../data/services/video_service.dart';

final videoServiceProvider = Provider((ref) => VideoService());

final feedProvider = FutureProvider<List<Video>>((ref) async {
  final service = ref.read(videoServiceProvider);
  return service.getFeed();
});
