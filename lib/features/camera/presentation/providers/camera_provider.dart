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
    state = AsyncValue.data(_service.controller);
  }

  Future<void> pauseRecording() async {
    await _service.pauseRecording();
    state = AsyncValue.data(_service.controller);
  }

  Future<void> resumeRecording() async {
    await _service.resumeRecording();
    state = AsyncValue.data(_service.controller);
  }

  Future<XFile?> stopRecording() async {
    final file = await _service.stopRecording();
    state = AsyncValue.data(_service.controller);
    return file;
  }

  Future<XFile?> takePicture() async {
    final file = await _service.takePicture();
    return file;
  }

  Future<void> switchCamera() async {
    state = const AsyncValue.loading();
    try {
      await _service.switchCamera();
      state = AsyncValue.data(_service.controller);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
