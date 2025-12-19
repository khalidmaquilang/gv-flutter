import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/draft_model.dart';
import '../../data/services/draft_service.dart';

final draftServiceProvider = Provider((ref) => DraftService());

final draftsProvider = FutureProvider<List<DraftModel>>((ref) async {
  final service = ref.watch(draftServiceProvider);
  return await service.getDrafts();
});

// A controller to perform actions and refresh the list
class DraftsController extends StateNotifier<AsyncValue<void>> {
  final DraftService _service;
  final Ref _ref;

  DraftsController(this._service, this._ref)
    : super(const AsyncValue.data(null));

  Future<void> saveDraft(DraftModel draft) async {
    state = const AsyncValue.loading();
    try {
      await _service.saveDraft(draft);
      _ref.refresh(draftsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteDraft(String id) async {
    // Optimistic update or just refresh? Refresh is safer for file I/O
    await _service.deleteDraft(id);
    _ref.refresh(draftsProvider);
  }
}

final draftsControllerProvider =
    StateNotifierProvider<DraftsController, AsyncValue<void>>((ref) {
      return DraftsController(ref.watch(draftServiceProvider), ref);
    });
