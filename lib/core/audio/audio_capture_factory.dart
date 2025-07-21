import 'dart:io';

import 'audio_capture_interface.dart';
import 'mobile_audio_capture.dart';
import 'hybrid_audio_capture.dart';

/// Factory for creating platform-specific audio capture implementations
class AudioCaptureFactory {
  /// Create the appropriate audio capture implementation for the current platform
  static AudioCaptureInterface createAudioCapture({
    AudioCaptureConfig? config,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return MobileAudioCapture(config: config);
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Use hybrid implementation that supports both microphone and system audio
      return HybridAudioCapture(config: config);
    } else {
      throw UnsupportedError(
        'Audio capture not supported on platform: ${Platform.operatingSystem}',
      );
    }
  }

  /// Check if audio capture is supported on the current platform
  static bool get isPlatformSupported {
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux;
  }

  /// Get platform-specific capabilities
  static Map<String, bool> get platformCapabilities {
    if (Platform.isAndroid || Platform.isIOS) {
      return {
        'microphone': true,
        'systemAudio': false,
        'virtualAudio': false,
        'backgroundProcessing': true,
      };
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return {
        'microphone': true,
        'systemAudio': true, // Hybrid implementation provides this
        'virtualAudio': true,
        'backgroundProcessing': true,
      };
    } else {
      return {
        'microphone': false,
        'systemAudio': false,
        'virtualAudio': false,
        'backgroundProcessing': false,
      };
    }
  }
}
