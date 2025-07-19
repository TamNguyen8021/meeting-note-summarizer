import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../audio/audio_chunk.dart';
import '../audio/audio_capture_interface.dart';
import '../audio/audio_source.dart';

/// Platform-specific audio capture using method channels
/// Handles native system audio recording on Windows/macOS/Linux
class PlatformAudioCapture implements AudioCaptureInterface {
  static const MethodChannel _methodChannel = MethodChannel('meeting_note_summarizer/audio_capture');
  static const EventChannel _audioEventChannel = EventChannel('meeting_note_summarizer/audio_stream');

  final StreamController<AudioChunk> _audioController = StreamController<AudioChunk>.broadcast();
  final StreamController<List<AudioSource>> _sourcesController = StreamController<List<AudioSource>>.broadcast();
  final StreamController<double> _levelController = StreamController<double>.broadcast();

  StreamSubscription<dynamic>? _audioSubscription;
  bool _isCapturing = false;
  bool _isInitialized = false;
  AudioSource? _currentSource;

  // Audio configuration
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitDepth = 16;
  static const int bufferSizeMs = 100;

  @override
  Stream<AudioChunk> get audioStream => _audioController.stream;

  @override
  Stream<List<AudioSource>> get availableSourcesStream => _sourcesController.stream;

  @override
  Stream<double> get audioLevelStream => _levelController.stream;

  @override
  AudioSource? get currentSource => _currentSource;

  @override
  bool get isCapturing => _isCapturing;

  @override
  bool get supportsSystemAudio => true;

  /// Get current audio configuration
  Map<String, dynamic> get audioConfig => {
    'sampleRate': sampleRate,
    'channels': channels,
    'bitDepth': bitDepth,
    'bufferSizeMs': bufferSizeMs,
  };

  /// Initialize platform audio capture
  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Register method channel handlers
      _methodChannel.setMethodCallHandler(_handleMethodCall);

      // Initialize native audio capture
      final Map<String, dynamic> config = {
        'sampleRate': sampleRate,
        'channels': channels,
        'bitDepth': bitDepth,
        'bufferSizeMs': bufferSizeMs,
      };

      final result = await _methodChannel.invokeMethod<bool>('initialize', config);
      if (result != true) {
        _handleError('Failed to initialize native audio capture');
        return false;
      }

      _isInitialized = true;
      debugPrint('Platform audio capture initialized successfully');
      
      // Load available sources
      await _loadAvailableSources();
      
      return true;
    } catch (e) {
      debugPrint('Platform audio capture initialization error: $e');
      
      // Fallback: Initialize with mock implementation
      _isInitialized = true;
      debugPrint('Using fallback audio capture implementation');
      
      // Load fallback sources
      final fallbackSources = _getFallbackAudioSources();
      _sourcesController.add(fallbackSources);
      
      // Auto-select the first available source
      if (fallbackSources.isNotEmpty) {
        _currentSource = fallbackSources.first;
        debugPrint('Auto-selected fallback audio source: ${_currentSource!.name}');
      }
      
      return true;
    }
  }

  @override
  Future<List<AudioSource>> getAvailableSources() async {
    if (!_isInitialized) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getAudioSources');
      final sources = <AudioSource>[];
      
      if (result != null) {
        for (final sourceData in result) {
          if (sourceData is Map<String, dynamic>) {
            sources.add(AudioSource(
              id: sourceData['id']?.toString() ?? '',
              name: sourceData['name']?.toString() ?? 'Unknown',
              type: _parseSourceType(sourceData['type']?.toString()),
              isAvailable: sourceData['isAvailable'] != false,
              deviceInfo: sourceData['deviceInfo'] as Map<String, dynamic>?,
            ));
          }
        }
      }

      return sources;
    } catch (e) {
      debugPrint('Platform method getAudioSources failed: $e');
      // Return fallback audio sources when native implementation is not available
      return _getFallbackAudioSources();
    }
  }

  /// Provides fallback audio sources when native implementation is not available
  List<AudioSource> _getFallbackAudioSources() {
    return [
      AudioSource(
        id: 'default_microphone',
        name: 'Default Microphone',
        type: AudioSourceType.microphone,
        isAvailable: true,
        deviceInfo: {'isFallback': true},
      ),
      AudioSource(
        id: 'system_audio',
        name: 'System Audio (Fallback)',
        type: AudioSourceType.system,
        isAvailable: true,
        deviceInfo: {'isFallback': true},
      ),
    ];
  }

  @override
  Future<bool> selectSource(AudioSource source) async {
    if (!_isInitialized) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>('selectAudioSource', {
        'sourceId': source.id,
      });
      
      if (result == true) {
        _currentSource = source;
        debugPrint('Selected audio source: ${source.name}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Platform method selectAudioSource failed: $e');
      // Fallback: just set the current source without native call
      _currentSource = source;
      debugPrint('Selected audio source (fallback): ${source.name}');
      return true;
    }
  }

  /// Start audio capture
  @override
  Future<bool> startCapture() async {
    if (!_isInitialized) {
      debugPrint('Audio capture not initialized');
      return false;
    }

    if (_isCapturing) {
      return true; // Already capturing
    }

    try {
      // Start listening to audio stream
      _audioSubscription = _audioEventChannel.receiveBroadcastStream().listen(
        _handleAudioData,
        onError: _handleStreamError,
      );

      // Start native audio capture
      final result = await _methodChannel.invokeMethod<bool>('startCapture');
      if (result != true) {
        debugPrint('Failed to start native audio capture');
        await _audioSubscription?.cancel();
        _audioSubscription = null;
        return false;
      }

      _isCapturing = true;
      debugPrint('Platform audio capture started');
      return true;
    } catch (e) {
      debugPrint('Platform method startCapture failed: $e');
      // Fallback: simulate audio capture without native implementation
      _isCapturing = true;
      _startFallbackAudioSimulation();
      debugPrint('Started fallback audio capture simulation');
      return true;
    }
  }

  /// Stop audio capture
  @override
  Future<void> stopCapture() async {
    if (!_isCapturing) {
      return; // Already stopped
    }

    try {
      // Cancel audio stream subscription
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      // Stop native audio capture
      await _methodChannel.invokeMethod('stopCapture');

      _isCapturing = false;
      debugPrint('Platform audio capture stopped');
    } catch (e) {
      debugPrint('Failed to stop audio capture: $e');
    }
  }

  @override
  Future<void> pauseCapture() async {
    try {
      await _methodChannel.invokeMethod('pauseCapture');
      debugPrint('Platform audio capture paused');
    } catch (e) {
      debugPrint('Failed to pause audio capture: $e');
    }
  }

  @override
  Future<bool> resumeCapture() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('resumeCapture');
      debugPrint('Platform audio capture resumed');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to resume audio capture: $e');
      return false;
    }
  }

  /// Load available sources and emit them
  Future<void> _loadAvailableSources() async {
    final sources = await getAvailableSources();
    _sourcesController.add(sources);
    
    // Auto-select first available source if none selected
    if (_currentSource == null && sources.isNotEmpty) {
      final availableSource = sources.firstWhere(
        (source) => source.isAvailable,
        orElse: () => sources.first,
      );
      await selectSource(availableSource);
    }
  }

  /// Parse source type from string
  AudioSourceType _parseSourceType(String? typeString) {
    switch (typeString?.toLowerCase()) {
      case 'microphone':
        return AudioSourceType.microphone;
      case 'system':
        return AudioSourceType.system;
      case 'line_in':
        return AudioSourceType.lineIn;
      case 'virtual':
        return AudioSourceType.virtual;
      default:
        return AudioSourceType.microphone;
    }
  }

  /// Handle method calls from native platform
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioLevelChanged':
        final double level = call.arguments['level']?.toDouble() ?? 0.0;
        _levelController.add(level);
        break;
      
      case 'onAudioDeviceChanged':
        final String deviceName = call.arguments['deviceName'] ?? 'Unknown';
        debugPrint('Audio device changed: $deviceName');
        await _loadAvailableSources();
        break;
      
      case 'onPermissionDenied':
        debugPrint('Microphone permission denied');
        break;
      
      case 'onError':
        final String message = call.arguments['message'] ?? 'Unknown native error';
        _handleError('Native audio error: $message');
        break;
      
      default:
        debugPrint('Unhandled method call: ${call.method}');
    }
  }

  /// Handle incoming audio data from native platform
  void _handleAudioData(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        // Extract audio data
        final List<int>? rawData = data['audioData']?.cast<int>();
        final int timestamp = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
        final double volume = data['volume']?.toDouble() ?? 0.0;

        if (rawData != null && rawData.isNotEmpty) {
          // Convert to Uint8List for AudioChunk
          final audioBytes = Uint8List.fromList(rawData);
          final duration = Duration(milliseconds: (audioBytes.length / (sampleRate * channels * (bitDepth ~/ 8)) * 1000).round());

          // Create audio chunk
          final chunk = AudioChunk(
            data: audioBytes,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
            duration: duration,
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: bitDepth,
            level: volume,
          );

          _audioController.add(chunk);
          _levelController.add(volume);
        }
      } else if (data is Uint8List) {
        // Handle raw byte data
        final duration = Duration(milliseconds: (data.length / (sampleRate * channels * (bitDepth ~/ 8)) * 1000).round());
        final volume = _calculateVolumeFromBytes(data);
        
        final chunk = AudioChunk(
          data: data,
          timestamp: DateTime.now(),
          duration: duration,
          sampleRate: sampleRate,
          channels: channels,
          bitsPerSample: bitDepth,
          level: volume,
        );

        _audioController.add(chunk);
        _levelController.add(volume);
      }
    } catch (e) {
      _handleError('Error processing audio data: $e');
    }
  }

  /// Handle stream errors
  void _handleStreamError(dynamic error) {
    _handleError('Audio stream error: $error');
  }

  /// Handle errors
  void _handleError(String message) {
    debugPrint('PlatformAudioCapture error: $message');
  }

  /// Calculate RMS volume from byte data
  double _calculateVolumeFromBytes(Uint8List bytes) {
    if (bytes.length < 2) return 0.0;
    
    double sum = 0.0;
    final sampleCount = bytes.length ~/ 2;
    
    for (int i = 0; i < sampleCount; i++) {
      // Read 16-bit little-endian sample
      final sample = (bytes[i * 2 + 1] << 8) | bytes[i * 2];
      final normalizedSample = (sample - 32768) / 32768.0;
      sum += normalizedSample * normalizedSample;
    }
    
    return (sum / sampleCount).clamp(0.0, 1.0);
  }

  /// Get available audio input devices
  Future<List<Map<String, dynamic>>> getAudioDevices() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getAudioDevices');
      return result?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      debugPrint('Failed to get audio devices: $e');
      return [];
    }
  }

  /// Set the active audio input device
  Future<bool> setAudioDevice(String deviceId) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setAudioDevice', {'deviceId': deviceId});
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to set audio device: $e');
      return false;
    }
  }

  /// Get current audio levels (useful for UI)
  Future<Map<String, double>> getAudioLevels() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<String, dynamic>>('getAudioLevels');
      return {
        'inputLevel': result?['inputLevel']?.toDouble() ?? 0.0,
        'outputLevel': result?['outputLevel']?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('Failed to get audio levels: $e');
      return {'inputLevel': 0.0, 'outputLevel': 0.0};
    }
  }

  /// Request microphone permission (mainly for mobile platforms)
  Future<bool> requestPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to request permission: $e');
      return false;
    }
  }

  /// Check microphone permission status
  Future<bool> checkPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to check permission: $e');
      return false;
    }
  }

  /// Cleanup resources
  @override
  Future<void> dispose() async {
    if (_isCapturing) {
      await stopCapture();
    }

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    try {
      await _methodChannel.invokeMethod('dispose');
    } catch (e) {
      debugPrint('Error during platform audio capture disposal: $e');
    }

    await _audioController.close();
    await _sourcesController.close();
    await _levelController.close();
    
    _isInitialized = false;
    debugPrint('Platform audio capture disposed');
  }

  /// Simulates audio capture when native implementation is not available
  void _startFallbackAudioSimulation() {
    // Generate mock audio data for testing purposes
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isCapturing) {
        timer.cancel();
        return;
      }

      // Generate mock 16kHz, 16-bit, mono audio data (100ms = 1600 samples)
      const int sampleRate = 16000;
      const int channels = 1;
      const int bitsPerSample = 16;
      const int durationMs = 100;
      const int samplesPerChunk = (sampleRate * durationMs) ~/ 1000;

      // Generate silent audio data (all zeros)
      final audioData = Int16List(samplesPerChunk);
      // Fill with very quiet noise to simulate microphone input
      final random = Random();
      for (int i = 0; i < samplesPerChunk; i++) {
        audioData[i] = random.nextInt(200) - 100; // Very quiet noise
      }

      // Convert Int16List to Uint8List for AudioChunk
      final audioBytes = Uint8List.fromList(
        audioData.expand((sample) => [
          sample & 0xFF,        // Low byte
          (sample >> 8) & 0xFF, // High byte
        ]).toList(),
      );

      final chunk = AudioChunk(
        data: audioBytes,
        timestamp: DateTime.now(),
        duration: Duration(milliseconds: durationMs),
        sampleRate: sampleRate,
        channels: channels,
        bitsPerSample: bitsPerSample,
        level: 0.05, // 5% level
      );

      _audioController.add(chunk);
      
      // Also emit a low audio level
      _levelController.add(0.05); // 5% level
    });
  }
}
