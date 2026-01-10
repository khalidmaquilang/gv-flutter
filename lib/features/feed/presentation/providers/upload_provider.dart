import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/video_service.dart';
import '../../../../core/errors/exceptions.dart';
import 'feed_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class UploadState {
  final bool isUploading;
  final bool isOptimizing; // New state
  final double progress;
  final String? error;
  final Map<String, dynamic>? validationErrors;
  final String? coverPath;

  UploadState({
    this.isUploading = false,
    this.isOptimizing = false,
    this.progress = 0.0,
    this.error,
    this.validationErrors,
    this.coverPath,
  });

  UploadState copyWith({
    bool? isUploading,
    bool? isOptimizing,
    double? progress,
    String? error,
    Map<String, dynamic>? validationErrors,
    String? coverPath,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      isOptimizing: isOptimizing ?? this.isOptimizing,
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
    required String privacy,
    required bool allowComments,
    String? musicId,
    String? overlayPath, // Accept overlay
    bool shouldOptimize = false,
    bool isFromGallery = false, // NEW: Track if uploaded from gallery
  }) async {
    state = state.copyWith(
      isUploading: true,
      isOptimizing: true, // Start optimizing first
      progress: 0.0,
      error: null,
      validationErrors: null,
      coverPath: null,
    );

    String finalPath = path;

    try {
      // 1. Optimize Video (if it's a video)
      if (path.toLowerCase().endsWith('.mp4') ||
          path.toLowerCase().endsWith('.mov')) {
        // Process if we have an overlay OR if explicit optimization is requested
        if (overlayPath != null || shouldOptimize) {
          final tempDir = await getTemporaryDirectory();
          final outputPath =
              '${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.mp4';

          // Command Construction
          String command;
          if (overlayPath != null) {
            // Burn overlay + Scale + Optimize
            // High Quality: Scale OVERLAY to match VIDEO (Reference).
            // This preserves the original video resolution and quality.
            // force_original_aspect_ratio=increase ensure overlay covers the video (for center crop)
            command =
                '-i "$path" -i "$overlayPath" -filter_complex "[1:v][0:v]scale2ref=flags=bicubic:force_original_aspect_ratio=increase[ovr_scaled][vid_ref];[vid_ref][ovr_scaled]overlay=x=(W-w)/2:y=(H-h)/2" -c:v libx264 -crf 23 -preset medium -c:a copy "$outputPath"';
          } else {
            // Just Optimize (Re-encode for compatibility, maintain resolution)
            command =
                '-i "$path" -c:v libx264 -crf 23 -preset medium -c:a copy "$outputPath"';
          }

          final session = await FFmpegKit.execute(command);
          final returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            finalPath = outputPath;
            // Optimization Done
          }
        }
        // else skip processing, upload raw
      }

      state = state.copyWith(
        isOptimizing: false,
      ); // Optimization done, uploading valid

      // Simulate partial progress for UX
      state = state.copyWith(progress: 0.1);
      // await Future.delayed(const Duration(milliseconds: 300)); // Remove artificial delay for speed
      state = state.copyWith(progress: 0.3);

      final success = await _videoService.uploadVideo(
        videoPath: finalPath,
        description: caption,
        privacy: privacy,
        allowComments: allowComments,
        musicId: musicId,
        fromCamera:
            !isFromGallery, // Invert: fromCamera = true when NOT from gallery
      );

      if (success) {
        state = state.copyWith(progress: 1.0);
        await Future.delayed(
          const Duration(seconds: 2),
        ); // Show 100% for 2 seconds
        state = state.copyWith(
          isUploading: false,
          coverPath: null,
          isOptimizing: false,
        );
      } else {
        // Should throw ideally, but if returns false
        state = state.copyWith(
          isUploading: false,
          isOptimizing: false,
          error: "Upload failed",
          coverPath: null,
        );
      }
    } on ValidationException catch (e) {
      state = state.copyWith(
        isUploading: false,
        isOptimizing: false,
        error: e.message,
        validationErrors: e.errors,
      );
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        isOptimizing: false,
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
