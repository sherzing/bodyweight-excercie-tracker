import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions.
class PermissionService {
  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission with explanation dialog if needed
  Future<bool> requestCameraPermission(BuildContext context) async {
    var status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      // First time or previously denied - request permission
      status = await Permission.camera.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Show dialog explaining why we need camera and how to enable it
      // ignore: use_build_context_synchronously
      final shouldOpenSettings = await _showPermissionDeniedDialog(context);
      if (shouldOpenSettings) {
        await openAppSettings();
        // Check again after returning from settings
        final newStatus = await Permission.camera.status;
        return newStatus.isGranted;
      }
      return false;
    }

    return false;
  }

  /// Show dialog when permission is permanently denied
  Future<bool> _showPermissionDeniedDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'This app needs camera access to track your exercises using pose detection. '
          'All processing happens on your device - no video data is ever uploaded.\n\n'
          'Please enable camera access in Settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show a brief explanation before requesting permission
  Future<bool> showPermissionRationale(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Access'),
        content: const Text(
          'To count your reps, this app uses your camera to detect your body position.\n\n'
          'All processing happens on your device - your privacy is protected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
