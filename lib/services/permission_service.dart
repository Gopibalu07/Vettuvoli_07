import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around permission_handler so it can be mocked in tests.
class PermissionService {
  /// Returns true if the microphone permission is (or becomes) granted.
  Future<bool> ensureMicrophone() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> isMicrophonePermanentlyDenied() =>
      Permission.microphone.isPermanentlyDenied;

  Future<bool> openSettings() => openAppSettings();
}
