import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  Future<void> initialize() async {
    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    await _initController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _initController(CameraDescription description) async {
    final oldController = _controller;

    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _controller!.initialize();

    if (oldController != null) {
      await oldController.dispose();
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_selectedCameraIndex]);
  }

  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    if (_controller!.value.isTakingPicture) return null;

    return await _controller!.takePicture();
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
