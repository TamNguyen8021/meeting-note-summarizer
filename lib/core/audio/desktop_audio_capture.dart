import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

import '../audio/audio_capture_interface.dart';
import '../audio/audio_source.dart';
import '../audio/audio_chunk.dart';

/// Desktop implementation placeholder for audio capture
/// Currently provides mock functionality until native implementation is ready
class DesktopAudioCapture implements AudioCaptureInterface {
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
  Timer? _mockAudioTimer;
  Timer? _levelTimer;
  final Random _random = Random();

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
        'note': 'Mock implementation - actual implementation pending',
      };

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Simulate initialization delay
      await Future.delayed(const Duration(milliseconds: 500));

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
    // Mock desktop audio sources
    final sources = <AudioSource>[
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
    ];

    return sources;
  }

  @override
  Future<bool> selectSource(AudioSource source) async {
    if (!_isInitialized) return false;

    _currentSource = source;
    return true;
  }

  @override
  Future<bool> startCapture() async {
    if (!_isInitialized || _currentSource == null || _isCapturing) {
      return false;
    }

    try {
      _isCapturing = true;
      _startMockAudioGeneration();
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

    _isCapturing = false;
    _stopMockAudioGeneration();
    _stopAudioLevelMonitoring();
  }

  @override
  Future<void> pauseCapture() async {
    if (!_isCapturing) return;

    _stopMockAudioGeneration();
    _stopAudioLevelMonitoring();
  }

  @override
  Future<bool> resumeCapture() async {
    if (!_isInitialized || _currentSource == null) return false;

    _startMockAudioGeneration();
    _startAudioLevelMonitoring();
    return true;
  }

  @override
  Future<void> dispose() async {
    _stopMockAudioGeneration();
    _stopAudioLevelMonitoring();

    await _audioStreamController.close();
    await _sourcesStreamController.close();
    await _audioLevelStreamController.close();

    _isInitialized = false;
  }

  /// Start generating mock audio data for testing
  void _startMockAudioGeneration() {
    _mockAudioTimer?.cancel();
    _mockAudioTimer = Timer.periodic(
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
    _mockAudioTimer?.cancel();
    _mockAudioTimer = null;
  }

  /// Generate a mock audio chunk
  void _generateMockAudioChunk() {
    final sampleCount = _config.bufferSizeInSamples;
    final byteCount = sampleCount * (_config.bitsPerSample ~/ 8);
    final audioData = Uint8List(byteCount);

    // Generate mock audio data (simple sine wave with noise)
    for (int i = 0; i < sampleCount; i++) {
      // Simple sine wave + noise for mock audio
      final frequency = 440.0; // A4 note
      final time = i / _config.sampleRate.toDouble();
      final sineWave = (sin(2 * pi * frequency * time) * 0.3);
      final noise = (_random.nextDouble() - 0.5) * 0.1;
      final sample = ((sineWave + noise) * 32767).round().clamp(-32768, 32767);

      // Convert to little-endian bytes
      final sampleBytes = sample < 0 ? sample + 65536 : sample;
      audioData[i * 2] = sampleBytes & 0xFF;
      audioData[i * 2 + 1] = (sampleBytes >> 8) & 0xFF;
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

        // Generate mock audio level
        final level = 0.1 + _random.nextDouble() * 0.4; // 0.1 to 0.5
        _audioLevelStreamController.add(level);
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
