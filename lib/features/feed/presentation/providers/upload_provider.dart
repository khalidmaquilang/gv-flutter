import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/video_service.dart';

class UploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final String? coverPath;

  UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
    this.coverPath,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    String? coverPath,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: error,
      coverPath: coverPath ?? this.coverPath,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier() : super(UploadState());

  Future<void> startUpload(
    String path,
    String caption, {
    String? coverPath,
  }) async {
    state = state.copyWith(
      isUploading: true,
      progress: 0.0,
      error: null,
      coverPath: coverPath ?? path,
    );

    // Simulate progress since we are using a mock service
    // In real app, VideoService would accept a onSendProgress callback

    // 0%
    await Future.delayed(const Duration(milliseconds: 200));
    state = state.copyWith(progress: 0.1);

    // 30%
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(progress: 0.30);

    // 60%
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(progress: 0.60);

    // 90%
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(progress: 0.90);

    // Perform actual "upload" (which is just a mock call in service)
    final success = await VideoService().uploadVideo(path, caption);

    if (success) {
      state = state.copyWith(progress: 1.0);
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isUploading: false, coverPath: null);
    } else {
      state = state.copyWith(
        isUploading: false,
        error: "Upload failed",
        coverPath: null,
      );
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((
  ref,
) {
  return UploadNotifier();
});
