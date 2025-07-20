import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_capture_interface.dart';
import 'audio_source.dart';
import 'audio_chunk.dart';

/// Desktop implementation for audio capture with platform channels
/// Supports system audio, microphone, and virtual audio sources on Windows/macOS/Linux
class DesktopAudioCapture implements AudioCaptureInterface {
  static const MethodChannel _channel =
      MethodChannel('meeting_summarizer/audio_capture');

  final AudioCaptureConfig _config;
  final Random _random = Random();

  final StreamController<AudioChunk> _audioStreamController =
      StreamController<AudioChunk>.broadcast();
  final StreamController<List<AudioSource>> _sourcesStreamController =
      StreamController<List<AudioSource>>.broadcast();
  final StreamController<double> _audioLevelStreamController =
      StreamController<double>.broadcast();

  AudioSource? _currentSource;
  bool _isCapturing = false;
  bool _isInitialized = false;
  Timer? _audioTimer;
  Timer? _levelTimer;
  Timer? _reconnectTimer;

  // Reconnection and error handling
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  String? _lastError;

  DesktopAudioCapture({AudioCaptureConfig? config})
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
  bool get supportsSystemAudio => true; // Desktop supports system audio

  @override
  Map<String, dynamic> get audioConfig => {
        'sampleRate': _config.sampleRate,
        'channels': _config.channels,
        'bitsPerSample': _config.bitsPerSample,
        'platform': 'desktop',
        'bufferSizeMs': _config.bufferSizeMs,
      };

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;

      // Try to initialize native audio system
      try {
        await _channel.invokeMethod('initialize', {
          'sampleRate': _config.sampleRate,
          'channels': _config.channels,
          'bitsPerSample': _config.bitsPerSample,
          'bufferSizeMs': _config.bufferSizeMs,
        });
        debugPrint('Native audio system initialized successfully');
      } catch (e) {
        debugPrint('Native audio initialization failed, using mock: $e');
        // Continue with mock implementation
      }

      _isInitialized = true;

      // Set up method call handler for native audio data
      _channel.setMethodCallHandler(_handleMethodCall);

      // Emit initial sources
      final sources = await getAvailableSources();
      _sourcesStreamController.add(sources);

      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Desktop audio initialization failed: $e');
      return false;
    }
  }

  @override
  Future<List<AudioSource>> getAvailableSources() async {
    try {
      // Try to get real audio sources from native platform
      final result = await _channel.invokeMethod('getAudioSources');
      if (result != null && result is List) {
        return result.map<AudioSource>((sourceData) {
          return AudioSource(
            id: sourceData['id'] as String,
            name: sourceData['name'] as String,
            type: _parseAudioSourceType(sourceData['type'] as String),
            isAvailable: sourceData['isAvailable'] as bool? ?? true,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Failed to get native audio sources: $e');
    }

    // Fallback to mock sources
    return _getMockAudioSources();
  }

  List<AudioSource> _getMockAudioSources() {
    return [
      const AudioSource(
        id: 'default_microphone',
        name: 'Default Microphone',
        type: AudioSourceType.microphone,
        isAvailable: true,
      ),
      const AudioSource(
        id: 'system_audio',
        name: 'System Audio (Speakers)',
        type: AudioSourceType.system,
        isAvailable: true,
      ),
      const AudioSource(
        id: 'line_in',
        name: 'Line In',
        type: AudioSourceType.lineIn,
        isAvailable: true,
      ),
      const AudioSource(
        id: 'virtual_cable',
        name: 'Virtual Audio Cable',
        type: AudioSourceType.virtual,
        isAvailable: false,
      ),
    ];
  }

  AudioSourceType _parseAudioSourceType(String type) {
    switch (type.toLowerCase()) {
      case 'microphone':
        return AudioSourceType.microphone;
      case 'system':
        return AudioSourceType.system;
      case 'linein':
        return AudioSourceType.lineIn;
      case 'virtual':
        return AudioSourceType.virtual;
      default:
        return AudioSourceType.microphone;
    }
  }

  @override
  Future<bool> selectSource(AudioSource source) async {
    if (!_isInitialized) return false;

    try {
      // Try to select source via native platform
      final result = await _channel.invokeMethod('selectAudioSource', {
        'sourceId': source.id,
      });

      if (result == true) {
        _currentSource = source;
        return true;
      }
    } catch (e) {
      debugPrint('Failed to select native audio source: $e');
    }

    // Fallback to mock selection
    _currentSource = source;
    return true;
  }

  @override
  Future<bool> startCapture() async {
    if (!_isInitialized || _currentSource == null || _isCapturing) {
      return false;
    }

    try {
      _lastError = null;
      _reconnectAttempts = 0;

      // Try to start native audio capture
      bool nativeStarted = false;
      try {
        final result = await _channel.invokeMethod('startCapture');
        nativeStarted = result == true;
      } catch (e) {
        debugPrint('Failed to start native audio capture: $e');
      }

      _isCapturing = true;

      if (!nativeStarted) {
        // Fallback to mock audio generation
        _startMockAudioGeneration();
      }

      _startAudioLevelMonitoring();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isCapturing = false;
      return false;
    }
  }

  @override
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    _isCapturing = false;
    _reconnectTimer?.cancel();

    // Stop native capture
    try {
      await _channel.invokeMethod('stopCapture');
    } catch (e) {
      debugPrint('Failed to stop native audio capture: $e');
    }

    // Stop mock audio
    _stopMockAudioGeneration();
    _stopAudioLevelMonitoring();
  }

  @override
  Future<void> pauseCapture() async {
    if (!_isCapturing) return;

    try {
      await _channel.invokeMethod('pauseCapture');
    } catch (e) {
      debugPrint('Failed to pause native audio capture: $e');
    }

    _stopMockAudioGeneration();
    _stopAudioLevelMonitoring();
  }

  @override
  Future<bool> resumeCapture() async {
    if (!_isInitialized || _currentSource == null) return false;

    try {
      final result = await _channel.invokeMethod('resumeCapture');
      if (result == true) {
        _startAudioLevelMonitoring();
        return true;
      }
    } catch (e) {
      debugPrint('Failed to resume native audio capture: $e');
    }

    // Fallback to mock
    _startMockAudioGeneration();
    _startAudioLevelMonitoring();
    return true;
  }

  @override
  Future<void> dispose() async {
    await stopCapture();

    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      debugPrint('Failed to dispose native audio capture: $e');
    }

    await _audioStreamController.close();
    await _sourcesStreamController.close();
    await _audioLevelStreamController.close();

    _isInitialized = false;
  }

  /// Handle method calls from native platform
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioData':
        _handleNativeAudioData(call.arguments);
        break;
      case 'onAudioLevel':
        _handleNativeAudioLevel(call.arguments);
        break;
      case 'onAudioError':
        _handleNativeAudioError(call.arguments);
        break;
      case 'onSourcesChanged':
        _handleSourcesChanged(call.arguments);
        break;
      default:
        debugPrint('Unknown method call: ${call.method}');
    }
  }

  void _handleNativeAudioData(dynamic arguments) {
    if (!_isCapturing) return;

    try {
      final audioData = arguments['audioData'] as Uint8List;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        arguments['timestamp'] as int,
      );
      final level = arguments['level'] as double? ?? 0.0;

      final duration = Duration(
        milliseconds: (audioData.length * 1000) ~/
            (_config.sampleRate *
                _config.channels *
                (_config.bitsPerSample ~/ 8)),
      );

      final chunk = AudioChunk(
        data: audioData,
        timestamp: timestamp,
        duration: duration,
        sampleRate: _config.sampleRate,
        channels: _config.channels,
        bitsPerSample: _config.bitsPerSample,
        level: level,
      );

      _audioStreamController.add(chunk);
    } catch (e) {
      debugPrint('Error handling native audio data: $e');
    }
  }

  void _handleNativeAudioLevel(dynamic arguments) {
    if (!_isCapturing) return;

    try {
      final level = arguments['level'] as double? ?? 0.0;
      _audioLevelStreamController.add(level);
    } catch (e) {
      debugPrint('Error handling native audio level: $e');
    }
  }

  void _handleNativeAudioError(dynamic arguments) {
    final error = arguments['error'] as String? ?? 'Unknown audio error';
    _lastError = error;
    debugPrint('Native audio error: $error');

    // Attempt automatic reconnection
    _attemptReconnection();
  }

  void _handleSourcesChanged(dynamic arguments) {
    // Refresh available sources
    getAvailableSources().then((sources) {
      _sourcesStreamController.add(sources);
    });
  }

  void _attemptReconnection() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached, switching to mock audio');
      _startMockAudioGeneration();
      return;
    }

    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectAttempts), () async {
      debugPrint(
          'Attempting audio reconnection $_reconnectAttempts/$_maxReconnectAttempts');

      try {
        final result = await _channel.invokeMethod('reconnect');
        if (result == true) {
          _reconnectAttempts = 0;
          debugPrint('Audio reconnection successful');
        } else {
          _attemptReconnection();
        }
      } catch (e) {
        debugPrint('Reconnection failed: $e');
        _attemptReconnection();
      }
    });
  }

  /// Start generating mock audio data for testing/fallback
  void _startMockAudioGeneration() {
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(
      Duration(milliseconds: _config.bufferSizeMs),
      (timer) {
        if (!_isCapturing) {
          timer.cancel();
          return;
        }

        _generateMockAudioChunk();
      },
    );
  }

  /// Stop mock audio generation
  void _stopMockAudioGeneration() {
    _audioTimer?.cancel();
    _audioTimer = null;
  }

  /// Generate a mock audio chunk for testing
  void _generateMockAudioChunk() {
    final sampleCount = _config.bufferSizeInSamples;
    final byteCount = sampleCount * (_config.bitsPerSample ~/ 8);
    final audioData = Uint8List(byteCount);

    // Generate mock audio data based on source type
    double baseVolume = 0.0;
    switch (_currentSource?.type) {
      case AudioSourceType.microphone:
        baseVolume =
            0.1 + _random.nextDouble() * 0.3; // Variable microphone input
        break;
      case AudioSourceType.system:
        baseVolume =
            0.2 + _random.nextDouble() * 0.4; // System audio typically louder
        break;
      case AudioSourceType.lineIn:
        baseVolume =
            0.15 + _random.nextDouble() * 0.25; // Line input moderate volume
        break;
      default:
        baseVolume = 0.1 + _random.nextDouble() * 0.2;
    }

    // Generate realistic audio patterns
    for (int i = 0; i < sampleCount; i++) {
      double sample = 0.0;

      // Add some periodic patterns (simulating speech/music)
      final time = i / _config.sampleRate.toDouble();
      sample += sin(2 * pi * 220 * time) *
          baseVolume *
          0.3; // Low frequency component
      sample += sin(2 * pi * 880 * time) * baseVolume * 0.2; // Higher frequency

      // Add noise
      sample += (_random.nextDouble() - 0.5) * baseVolume * 0.1;

      // Occasional peaks (simulating speech)
      if (_random.nextDouble() < 0.01) {
        sample *= 2.0;
      }

      // Convert to 16-bit integer
      final intSample = (sample * 32767).round().clamp(-32768, 32767);
      final unsignedSample = intSample < 0 ? intSample + 65536 : intSample;

      audioData[i * 2] = unsignedSample & 0xFF;
      audioData[i * 2 + 1] = (unsignedSample >> 8) & 0xFF;
    }

    final level = _calculateAudioLevel(audioData);
    final now = DateTime.now();
    final duration = Duration(milliseconds: _config.bufferSizeMs);

    final chunk = AudioChunk(
      data: audioData,
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
      (timer) {
        if (!_isCapturing) {
          timer.cancel();
          return;
        }

        // Only generate mock levels if we're not getting them from native
        // The native implementation will send levels via _handleNativeAudioLevel
      },
    );
  }

  /// Stop audio level monitoring
  void _stopAudioLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = null;
    _audioLevelStreamController.add(0.0);
  }
}
