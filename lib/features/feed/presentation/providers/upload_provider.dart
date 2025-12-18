import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/video_service.dart';
import '../../../../core/errors/exceptions.dart';
import 'feed_provider.dart';

class UploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final Map<String, dynamic>? validationErrors;
  final String? coverPath;

  UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
    this.validationErrors,
    this.coverPath,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    Map<String, dynamic>? validationErrors,
    String? coverPath,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: error,
      validationErrors: validationErrors ?? this.validationErrors,
      coverPath: coverPath ?? this.coverPath,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final VideoService _videoService;

  UploadNotifier(this._videoService) : super(UploadState());

  Future<void> startUpload(
    String path,
    String caption, {
    required String coverPath,
    required String privacy,
    required bool allowComments,
    int? musicId,
  }) async {
    state = state.copyWith(
      isUploading: true,
      progress: 0.0,
      error: null,
      validationErrors: null,
      coverPath: coverPath,
    );

    try {
      // Simulate partial progress for UX
      state = state.copyWith(progress: 0.1);
      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(progress: 0.3);

      final success = await _videoService.uploadVideo(
        videoPath: path,
        thumbnailPath: coverPath,
        description: caption,
        privacy: privacy,
        allowComments: allowComments,
        musicId: musicId,
      );

      if (success) {
        state = state.copyWith(progress: 1.0);
        await Future.delayed(const Duration(seconds: 1));
        state = state.copyWith(isUploading: false, coverPath: null);
      } else {
        // Should throw ideally, but if returns false
        state = state.copyWith(
          isUploading: false,
          error: "Upload failed",
          coverPath: null,
        );
      }
    } on ValidationException catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.message,
        validationErrors: e.errors,
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: "Upload failed: ${e.toString()}",
        coverPath: null,
      );
    }
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((
  ref,
) {
  return UploadNotifier(ref.watch(videoServiceProvider));
});
