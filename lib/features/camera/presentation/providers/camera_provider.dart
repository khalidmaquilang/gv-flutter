import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/camera_service.dart';

final cameraServiceProvider = Provider((ref) => CameraService());

final cameraControllerProvider =
    StateNotifierProvider.autoDispose<
      CameraNotifier,
      AsyncValue<CameraController?>
    >((ref) {
      return CameraNotifier(ref.read(cameraServiceProvider));
    });

class CameraNotifier extends StateNotifier<AsyncValue<CameraController?>> {
  final CameraService _service;

  CameraNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _service.initialize();
      state = AsyncValue.data(_service.controller);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> startRecording() async {
    await _service.startRecording();
    // Force rebuild or update state to reflect recording status if needed
    // Typically state update mechanism is needed to show recording indicator
    state = AsyncValue.data(_service.controller);
  }

  Future<XFile?> stopRecording() async {
    final file = await _service.stopRecording();
    state = AsyncValue.data(_service.controller);
    return file;
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
