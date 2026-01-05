import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Service for managing camera capture and frame processing.
/// Provides a stream of camera images for pose detection.
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;

  /// Callback for processing camera frames
  void Function(InputImage inputImage)? onFrame;

  /// Whether the camera is initialized and ready
  bool get isInitialized => _isInitialized;

  /// The camera controller (null if not initialized)
  CameraController? get controller => _controller;

  /// Get the current camera description
  CameraDescription? get camera => _controller?.description;

  /// Initialize available cameras
  Future<void> initialize({
    CameraLensDirection preferredDirection = CameraLensDirection.front,
  }) async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      throw CameraException('NoCameras', 'No cameras available on this device');
    }

    // Find preferred camera (front for exercise tracking)
    final camera = _cameras!.firstWhere(
      (c) => c.lensDirection == preferredDirection,
      orElse: () => _cameras!.first,
    );

    await _initializeController(camera);
  }

  Future<void> _initializeController(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // Balance between quality and performance
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    _isInitialized = true;
  }

  /// Start streaming camera frames for processing
  Future<void> startImageStream() async {
    if (!_isInitialized || _controller == null) {
      throw StateError('Camera not initialized');
    }

    await _controller!.startImageStream(_processImage);
  }

  /// Stop streaming camera frames
  Future<void> stopImageStream() async {
    if (_controller?.value.isStreamingImages ?? false) {
      await _controller!.stopImageStream();
    }
  }

  void _processImage(CameraImage image) {
    // Skip if already processing a frame (maintain performance)
    if (_isProcessing || onFrame == null) return;
    _isProcessing = true;

    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage != null) {
        onFrame!(inputImage);
      }
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertToInputImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Handle plane data
    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentDirection = _controller?.description.lensDirection;
    final newDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final newCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == newDirection,
      orElse: () => _cameras!.first,
    );

    await stopImageStream();
    await _controller?.dispose();
    await _initializeController(newCamera);
  }

  /// Dispose of camera resources
  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
