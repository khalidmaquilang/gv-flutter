import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/draft_model.dart';

class DraftService {
  Future<File> get _draftsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/drafts.json');
  }

  Future<List<DraftModel>> getDrafts() async {
    try {
      final file = await _draftsFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      List<DraftModel> drafts = jsonList
          .map((e) => DraftModel.fromJson(e))
          .toList();

      // Fix paths if app sandbox changed
      final appDir = await getApplicationDocumentsDirectory();
      final draftsDir = Directory('${appDir.path}/drafts');

      return drafts.map((draft) {
        List<String> fixedPaths = [];
        for (String path in draft.videoPaths) {
          final f = File(path);
          if (f.existsSync()) {
            fixedPaths.add(path);
          } else {
            // Try to find in current drafts dir
            final filename = path.split('/').last;
            final newPath = '${draftsDir.path}/$filename';
            if (File(newPath).existsSync()) {
              fixedPaths.add(newPath);
            } else {
              // Only keep if we can't find it (will trigger warning later, but at least we tried)
              // Or should we remove it?
              // Let's keep it so logic downstream knows it's missing
              fixedPaths.add(path);
            }
          }
        }
        // Return new draft with fixed paths (Wait, DraftModel fields are final, need copyWith or new instance)
        // Since DraftModel doesn't have copyWith yet, I'll create new instance
        return DraftModel(
          id: draft.id,
          videoPaths: fixedPaths,
          thumbnailPath: draft.thumbnailPath,
          caption: draft.caption,
          createdAt: draft.createdAt,
          sound: draft.sound,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveDraft(DraftModel draft) async {
    final file = await _draftsFile;
    List<DraftModel> drafts = await getDrafts();

    // Check if updating existing draft
    int existingIndex = drafts.indexWhere((d) => d.id == draft.id);
    if (existingIndex != -1) {
      // Remove old version so we can put updated one at top (or keep position?)
      // Usually "Save" implies "Last Modified", so top is good.
      drafts.removeAt(existingIndex);
    }

    drafts.insert(0, draft); // Add to top

    await file.writeAsString(
      jsonEncode(drafts.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteDraft(String id) async {
    final file = await _draftsFile;
    List<DraftModel> drafts = await getDrafts();

    drafts.removeWhere((d) => d.id == id);

    await file.writeAsString(
      jsonEncode(drafts.map((e) => e.toJson()).toList()),
    );
  }
}
