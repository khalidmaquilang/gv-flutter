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
      return jsonList.map((e) => DraftModel.fromJson(e)).toList();
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
