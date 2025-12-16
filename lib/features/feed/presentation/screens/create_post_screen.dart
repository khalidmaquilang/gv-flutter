import 'dart:io';
import 'package:camera/camera.dart' hide ImageFormat;
import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';

import '../../../camera/data/models/sound_model.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/upload_provider.dart';
import '../providers/drafts_provider.dart';
import '../../data/models/draft_model.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final List<XFile> files;
  final bool isVideo;
  final Sound? sound;
  final String? initialCaption;
  final String? draftId;

  const CreatePostScreen({
    super.key,
    required this.files,
    this.isVideo = true,
    this.sound,
    this.initialCaption,
    this.draftId,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _privacy = 'Public'; // Public, Friends, Private
  bool _allowComments = true;

  // For additional photos
  late List<XFile> _currentFiles;

  VideoPlayerController? _videoController;

  bool _isPosting = false;
  // bool _isVideoInitError = false; // logic changed, removed
  String? _previewThumbnail;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.initialCaption ?? "";
    _currentFiles = List.from(widget.files);
    if (widget.isVideo && _currentFiles.isNotEmpty) {
      // _initializeVideoController(); // Removed in favor of thumbnail
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (_currentFiles.isEmpty) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final thumb = await VideoThumbnail.thumbnailFile(
        video: _currentFiles.first.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );
      if (mounted) {
        setState(() {
          _previewThumbnail = thumb;
        });
      }
    } catch (e) {
      debugPrint("Error generating thumbnail: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _onSaveDraft() async {
    final path = _currentFiles.first.path;
    final caption = widget.isVideo
        ? _descriptionController.text
        : "${_titleController.text}\n${_descriptionController.text}";

    String? coverPath;
    if (widget.isVideo) {
      final tempDir = await getTemporaryDirectory();
      coverPath = await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 150,
        quality: 75,
      );
    } else {
      coverPath = path;
    }

    // Determine Draft ID
    String finalDraftId = const Uuid().v4();
    bool isUpdate = false;

    if (widget.draftId != null) {
      // Ask User: Update or Save As New?
      final String? choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.update, color: Colors.blue),
                title: const Text(
                  "Save and Exit (Overwrite)",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(context).pop('update'),
              ),
              ListTile(
                leading: const Icon(Icons.file_copy, color: Colors.green),
                title: const Text(
                  "Save as New Draft",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(context).pop('new'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );

      if (choice == null) return; // Cancelled

      if (choice == 'update') {
        finalDraftId = widget.draftId!;
        isUpdate = true;
      }
      // else 'new' -> keeps finalDraftId as new UUID
    }

    // COPY FILES TO PERMANENT STORAGE
    List<String> persistentPaths = [];
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final draftsDir = Directory('${appDir.path}/drafts');
      if (!await draftsDir.exists()) {
        await draftsDir.create(recursive: true);
      }

      for (int i = 0; i < _currentFiles.length; i++) {
        final xFile = _currentFiles[i];
        final File sourceFile = File(xFile.path);

        // Check if source exists (it might be missing if coming from an old broken draft)
        if (!sourceFile.existsSync()) {
          debugPrint("Warning: Source file missing for draft: ${xFile.path}");
          continue;
        }

        // Use draftId + index + timestamp to ensure uniqueness
        final String fileName =
            "${finalDraftId}_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4";
        final String newPath = '${draftsDir.path}/$fileName';

        // Copy the file
        await sourceFile.copy(newPath);
        persistentPaths.add(newPath);
      }
    } catch (e) {
      debugPrint("Error moving draft files to permanent storage: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save draft files: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (persistentPaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No valid video files to save.")),
        );
      }
      return;
    }

    final draft = DraftModel(
      id: finalDraftId,
      videoPaths: persistentPaths, // Use persistent paths
      thumbnailPath: coverPath,
      caption: caption,
      createdAt: DateTime.now(),
      sound: widget.sound,
    );

    if (!mounted) return;

    await ref.read(draftsControllerProvider.notifier).saveDraft(draft);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isUpdate ? "Draft updated!" : "Draft saved!")),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _onPost() async {
    // Start background upload
    final path = _currentFiles.first.path;
    final caption = widget.isVideo
        ? _descriptionController.text
        : "${_titleController.text}\n${_descriptionController.text}";

    String? coverPath;

    // Generate thumbnail if it's a video
    if (widget.isVideo) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Preparing upload...")));

      final tempDir = await getTemporaryDirectory();
      coverPath = await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 150, // smaller for notification
        quality: 75,
      );
    } else {
      // It's a photo, use the file itself
      coverPath = path;
    }

    if (!mounted) return;

    ref
        .read(uploadProvider.notifier)
        .startUpload(path, caption, coverPath: coverPath);

    // Navigate back to feed immediately
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Post"),
        // Post button removed from here
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Media Preview & Description row (For Video)
                  // For Photo, we might keep separate if needed, but let's try to unify or adapt
                  if (widget.isVideo)
                    _buildVideoAndDescription()
                  else ...[
                    _buildPhotoPreview(),
                    const SizedBox(height: 16),
                    // 1b. Title (Photo Only)
                    const Text(
                      "Title",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Enter a catchy title",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 2b. Description (Photo Only - Full width)
                    const Text(
                      "Description",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    _buildDescriptionField(lines: 4),
                  ],

                  const SizedBox(height: 24),

                  // 3. Privacy
                  _buildPrivacySelector(),

                  const SizedBox(height: 24),

                  // 4. Settings (Comments, etc.)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Allow Comments",
                        style: TextStyle(color: Colors.white70),
                      ),
                      Switch(
                        value: _allowComments,
                        onChanged: (val) =>
                            setState(() => _allowComments = val),
                        activeColor: AppColors.neonPink,
                        activeTrackColor: AppColors.neonPink.withOpacity(0.3),
                        inactiveThumbColor: Colors.white54,
                        inactiveTrackColor: Colors.white10,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Actions
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildVideoAndDescription() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover / Thumbnail
        Container(
          height: 150,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_previewThumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_previewThumbnail!),
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),

              // Edit Cover Button Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Edit Cover feature coming soon!"),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Edit Cover",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Description Field Layout
        Expanded(
          child: SizedBox(
            height: 150, // Match cover height
            child: _buildDescriptionField(
              lines: 6,
              hint: "Describe your video...",
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField({
    int lines = 4,
    String hint = "What's on your mind?",
  }) {
    return TextField(
      controller: _descriptionController,
      style: const TextStyle(color: Colors.white),
      maxLines: lines,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _currentFiles.length + 1, // +1 for Add button
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == _currentFiles.length) {
            // Add Button
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Add Photo feature coming soon!"),
                  ),
                );
              },
              child: Container(
                width: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white70,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Add",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          final file = _currentFiles[index];
          return Stack(
            children: [
              Container(
                width: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(File(file.path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentFiles.removeAt(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrivacySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Who can watch this video",
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _privacy,
              dropdownColor: const Color(0xFF1E1E1E),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                if (val != null) setState(() => _privacy = val);
              },
              items: [
                "Public",
                "Friends",
                "Private",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepVoid,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        // Ensure it respects bottom notch/safe area
        child: Row(
          children: [
            // Drafts Button
            Expanded(
              child: OutlinedButton(
                onPressed: _onSaveDraft,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Drafts",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Post Button
            Expanded(
              child: ElevatedButton(
                onPressed: _isPosting ? null : _onPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Post",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
