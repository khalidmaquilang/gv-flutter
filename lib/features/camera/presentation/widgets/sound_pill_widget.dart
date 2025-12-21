import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/sound_model.dart';

class SoundPillWidget extends StatelessWidget {
  final Sound? selectedSound;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool isRecording;
  final bool hasRecordedFiles;

  const SoundPillWidget({
    Key? key,
    required this.selectedSound,
    required this.onTap,
    required this.onClear,
    this.isRecording = false,
    this.hasRecordedFiles = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Logic for disabling touches (from VideoRecorder logic)
    // If recording or has files (and we are in recorder), we disable.
    // But PreviewScreen allows changing sound unless implemented otherwise.
    // The previous PreviewScreen logic allowed picking sound anytime.
    // So we'll pass `isRecording` and `hasRecordedFiles` from parent.

    bool isDisabled = isRecording || hasRecordedFiles;

    return IgnorePointer(
      ignoring: isDisabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.0 : 1.0,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.music_note,
                        color: AppColors.neonCyan,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedSound?.title ?? "Add Sound",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (selectedSound != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onClear,
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
