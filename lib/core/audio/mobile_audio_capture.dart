import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_capture_interface.dart';
import 'audio_source.dart';
import 'audio_chunk.dart';

/// Mobile implementation of audio capture using the record package
/// Supports microphone capture on iOS and Android
class MobileAudioCapture implements AudioCaptureInterface {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioCaptureConfig _config;

  final StreamController<AudioChunk> _audioStreamController =
      StreamController<AudioChunk>.broadcast();
  final StreamController<List<AudioSource>> _sourcesStreamController =
      StreamController<List<AudioSource>>.broadcast();
  final StreamController<double> _audioLevelStreamController =
      StreamController<double>.broadcast();

  AudioSource? _currentSource;
  bool _isCapturing = false;
  bool _isInitialized = false;
  Timer? _levelTimer;

  MobileAudioCapture({AudioCaptureConfig? config})
      : _config = config ?? const AudioCaptureConfig();

  @override
  Stream<AudioChunk> get audioStream => _audioStreamController.stream;

  @override
  Stream<List<AudioSource>> get availableSourcesStream =>
      _sourcesStreamController.stream;

  @override
  Stream<double> get audioLevelStream => _audioLevelStreamController.stream;

  @override
  AudioSource? get currentSource => _currentSource;

  @override
  bool get isCapturing => _isCapturing;

  @override
  bool get supportsSystemAudio => false; // Revert to working state

  @override
  Map<String, dynamic> get audioConfig => {
        'sampleRate': _config.sampleRate,
        'channels': _config.channels,
        'bitsPerSample': _config.bitsPerSample,
        'platform': 'mobile',
      };

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }

      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        return false;
      }

      _isInitialized = true;

      // Emit initial sources
      final sources = await getAvailableSources();
      _sourcesStreamController.add(sources);

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<AudioSource>> getAvailableSources() async {
    // Simplified mobile sources - only microphone for now
    final sources = <AudioSource>[
      const AudioSource(
        id: 'default_microphone',
        name: 'Default Microphone',
        type: AudioSourceType.microphone,
        isAvailable: true,
      ),
    ];

    // Check if microphone is available
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        sources.first = AudioSource(
          id: sources.first.id,
          name: sources.first.name,
          type: sources.first.type,
          isAvailable: false,
        );
      }
    } catch (e) {
      // Handle error silently, return basic source
    }

    return sources;
  }

  @override
  Future<bool> selectSource(AudioSource source) async {
    if (!_isInitialized) return false;

    // On mobile, we typically only have microphone
    if (source.type == AudioSourceType.microphone) {
      _currentSource = source;
      return true;
    }

    return false;
  }

  @override
  Future<bool> startCapture() async {
    if (!_isInitialized || _currentSource == null || _isCapturing) {
      return false;
    }

    try {
      // Use standard recording settings
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
      );

      // Start recording to stream
      final stream = await _recorder.startStream(config);
      _isCapturing = true;

      // Process audio stream
      stream.listen(
        _processAudioData,
        onError: (error) {
          _handleAudioError(error);
        },
        onDone: () {
          _isCapturing = false;
        },
      );

      // Start audio level monitoring
      _startAudioLevelMonitoring();

      return true;
    } catch (e) {
      _isCapturing = false;
      return false;
    }
  }

  @override
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _recorder.stop();
      _isCapturing = false;
      _stopAudioLevelMonitoring();
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Future<void> pauseCapture() async {
    if (!_isCapturing) return;

    try {
      await _recorder.pause();
      _stopAudioLevelMonitoring();
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Future<bool> resumeCapture() async {
    if (_isCapturing) return true;

    try {
      await _recorder.resume();
      _startAudioLevelMonitoring();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _stopAudioLevelMonitoring();
    await stopCapture();
    await _recorder.dispose();

    await _audioStreamController.close();
    await _sourcesStreamController.close();
    await _audioLevelStreamController.close();

    _isInitialized = false;
  }

  /// Process incoming audio data and create AudioChunk objects
  void _processAudioData(Uint8List data) {
    if (!_isCapturing || data.isEmpty) return;

    final now = DateTime.now();
    final duration = Duration(
        milliseconds: (data.length * 1000) ~/
            (_config.sampleRate *
                _config.channels *
                (_config.bitsPerSample ~/ 8)));

    // Calculate audio level for visualization
    final level = _calculateAudioLevel(data);

    final chunk = AudioChunk(
      data: data,
      timestamp: now,
      duration: duration,
      sampleRate: _config.sampleRate,
      channels: _config.channels,
      bitsPerSample: _config.bitsPerSample,
      level: level,
    );

    _audioStreamController.add(chunk);
  }

  /// Calculate audio level from raw data
  double _calculateAudioLevel(Uint8List data) {
    if (data.isEmpty) return 0.0;

    double sum = 0.0;
    final sampleCount = data.length ~/ 2; // 16-bit samples

    for (int i = 0; i < data.length; i += 2) {
      // Convert little-endian 16-bit sample to signed value
      int sample = data[i] | (data[i + 1] << 8);
      if (sample >= 32768) sample -= 65536;

      sum += (sample / 32768.0).abs();
    }

    return sampleCount > 0 ? sum / sampleCount : 0.0;
  }

  /// Start monitoring audio levels for UI feedback
  void _startAudioLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) async {
        if (!_isCapturing) {
          timer.cancel();
          return;
        }

        try {
          // Get current amplitude (if supported by the platform)
          final amplitude = await _recorder.getAmplitude();
          final level = amplitude.current.clamp(0.0, 1.0);
          _audioLevelStreamController.add(level);
        } catch (e) {
          // Fallback to default level if amplitude not available
          _audioLevelStreamController.add(0.1);
        }
      },
    );
  }

  /// Stop audio level monitoring
  void _stopAudioLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = null;
    _audioLevelStreamController.add(0.0);
  }

  /// Handle audio capture errors
  void _handleAudioError(dynamic error) {
    _isCapturing = false;
    _stopAudioLevelMonitoring();
    // Could emit error event here if needed
  }
}
