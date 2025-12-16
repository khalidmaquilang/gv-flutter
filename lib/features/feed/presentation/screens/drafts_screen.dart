import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/drafts_provider.dart';
import 'package:camera/camera.dart'; // for XFile
import 'package:test_flutter/features/camera/presentation/screens/preview_screen.dart';

class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftsProvider);

    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      appBar: AppBar(
        title: const Text("Drafts"),
        backgroundColor: Colors.transparent,
      ),
      body: draftsAsync.when(
        data: (drafts) {
          if (drafts.isEmpty) {
            return const Center(
              child: Text("No drafts", style: TextStyle(color: Colors.white54)),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(1),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
            ),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return GestureDetector(
                onTap: () {
                  // Open draft - Navigate to PreviewScreen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PreviewScreen(
                        files: draft.videoPaths
                            .map((p) => XFile(p))
                            .toList(), // Load all files
                        isVideo: true,
                        initialCaption: draft.caption,
                        fromDraft: true,
                        draftId: draft.id,
                        sound: draft.sound,
                      ),
                    ),
                  );
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text(
                        "Delete Draft?",
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        "Are you sure you want to delete this draft?",
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(draftsControllerProvider.notifier)
                                .deleteDraft(draft.id);
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (draft.thumbnailPath != null)
                      Image.file(File(draft.thumbnailPath!), fit: BoxFit.cover)
                    else
                      Container(color: Colors.grey[900]),

                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Text(
                        draft.createdAt.toString().split(' ')[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
