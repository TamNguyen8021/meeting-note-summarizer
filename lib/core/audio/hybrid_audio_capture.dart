import 'dart:io';

import 'audio_capture_interface.dart';
import 'audio_source.dart';
import 'audio_chunk.dart';
import 'mobile_audio_capture.dart';
import 'platform_audio_capture.dart';
import 'desktop_audio_capture.dart';

/// Hybrid audio capture that uses the best implementation for each source type
class HybridAudioCapture implements AudioCaptureInterface {
  AudioCaptureInterface? _activeCapture;
  AudioCaptureInterface? _microphoneCapture;
  AudioCaptureInterface? _systemCapture;

  HybridAudioCapture({AudioCaptureConfig? config}) {
    // Initialize microphone capture (always available)
    if (Platform.isAndroid || Platform.isIOS) {
      _microphoneCapture = MobileAudioCapture(config: config);
    } else {
      _microphoneCapture = PlatformAudioCapture();
    }

    // Initialize system capture (only on desktop)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        _systemCapture = DesktopAudioCapture(config: config);
      } catch (e) {
        // System capture not available, stick to microphone only
        _systemCapture = null;
      }
    }

    _activeCapture = _microphoneCapture;
  }

  @override
  Stream<AudioChunk> get audioStream =>
      _activeCapture?.audioStream ?? const Stream.empty();

  @override
  Stream<List<AudioSource>> get availableSourcesStream =>
      _activeCapture?.availableSourcesStream ?? const Stream.empty();

  @override
  Stream<double> get audioLevelStream =>
      _activeCapture?.audioLevelStream ?? const Stream.empty();

  @override
  AudioSource? get currentSource => _activeCapture?.currentSource;

  @override
  bool get isCapturing => _activeCapture?.isCapturing ?? false;

  @override
  bool get supportsSystemAudio => _systemCapture != null;

  @override
  Map<String, dynamic> get audioConfig => _activeCapture?.audioConfig ?? {};

  @override
  Future<bool> initialize() async {
    // Initialize microphone capture
    final micInitialized = await _microphoneCapture?.initialize() ?? false;

    // Try to initialize system capture if available
    bool systemInitialized = true;
    if (_systemCapture != null) {
      systemInitialized = await _systemCapture!.initialize();
      if (!systemInitialized) {
        _systemCapture = null; // Disable if initialization failed
      }
    }

    return micInitialized;
  }

  @override
  Future<List<AudioSource>> getAvailableSources() async {
    final sources = <AudioSource>[];

    // Always add microphone sources
    final micSources = await _microphoneCapture?.getAvailableSources() ?? [];
    sources.addAll(micSources);

    // Add system sources if available
    if (_systemCapture != null) {
      try {
        final systemSources = await _systemCapture!.getAvailableSources();
        // Only add system-type sources
        sources.addAll(systemSources.where((source) =>
            source.type == AudioSourceType.system ||
            source.type == AudioSourceType.virtual));
      } catch (e) {
        // System sources not available
      }
    }

    return sources;
  }

  @override
  Future<bool> selectSource(AudioSource source) async {
    // Determine which capture to use based on source type
    AudioCaptureInterface? targetCapture;

    switch (source.type) {
      case AudioSourceType.microphone:
      case AudioSourceType.lineIn:
        targetCapture = _microphoneCapture;
        break;
      case AudioSourceType.system:
      case AudioSourceType.virtual:
        targetCapture = _systemCapture;
        break;
      case AudioSourceType.unknown:
      default:
        targetCapture = _microphoneCapture; // Default to microphone
        break;
    }

    if (targetCapture == null) return false;

    // Stop current capture if different
    if (_activeCapture != targetCapture &&
        _activeCapture?.isCapturing == true) {
      await _activeCapture!.stopCapture();
    }

    _activeCapture = targetCapture;
    return await _activeCapture!.selectSource(source);
  }

  @override
  Future<bool> startCapture() async {
    return await _activeCapture?.startCapture() ?? false;
  }

  @override
  Future<void> stopCapture() async {
    await _activeCapture?.stopCapture();
  }

  @override
  Future<void> pauseCapture() async {
    await _activeCapture?.pauseCapture();
  }

  @override
  Future<bool> resumeCapture() async {
    return await _activeCapture?.resumeCapture() ?? false;
  }

  @override
  Future<void> dispose() async {
    await _microphoneCapture?.dispose();
    await _systemCapture?.dispose();
  }
}
