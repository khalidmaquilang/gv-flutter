import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  Future<void> initialize() async {
    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first, // Use back camera by default
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _controller!.initialize();
  }

  Future<void> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;

    await _controller!.startVideoRecording();
  }

  Future<XFile?> stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo)
      return null;

    return await _controller!.stopVideoRecording();
  }

  void dispose() {
    _controller?.dispose();
  }
}
