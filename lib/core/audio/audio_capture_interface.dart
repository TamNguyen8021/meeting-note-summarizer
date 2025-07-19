import 'dart:async';
import 'audio_source.dart';
import 'audio_chunk.dart';

/// Abstract interface for audio capture implementations
/// Platform-specific implementations handle actual audio capture
abstract class AudioCaptureInterface {
  /// Stream of audio chunks as they are captured
  Stream<AudioChunk> get audioStream;

  /// Stream of available audio sources
  Stream<List<AudioSource>> get availableSourcesStream;

  /// Current audio level (0.0 to 1.0) for visualization
  Stream<double> get audioLevelStream;

  /// Currently selected audio source
  AudioSource? get currentSource;

  /// Whether audio capture is currently active
  bool get isCapturing;

  /// Initialize the audio capture system
  /// Returns true if initialization was successful
  Future<bool> initialize();

  /// Get list of available audio sources
  Future<List<AudioSource>> getAvailableSources();

  /// Select an audio source for capture
  /// Returns true if the source was successfully selected
  Future<bool> selectSource(AudioSource source);

  /// Start audio capture with the selected source
  Future<bool> startCapture();

  /// Stop audio capture
  Future<void> stopCapture();

  /// Pause audio capture (if supported)
  Future<void> pauseCapture();

  /// Resume audio capture after pause
  Future<bool> resumeCapture();

  /// Clean up resources
  Future<void> dispose();

  /// Check if system audio capture is supported on this platform
  bool get supportsSystemAudio;

  /// Get platform-specific audio configuration
  Map<String, dynamic> get audioConfig;
}

/// Configuration for audio capture
class AudioCaptureConfig {
  /// Sample rate in Hz (default: 16000 for AI processing)
  final int sampleRate;

  /// Number of channels (default: 1 for mono)
  final int channels;

  /// Bits per sample (default: 16)
  final int bitsPerSample;

  /// Buffer size in milliseconds (default: 100ms)
  final int bufferSizeMs;

  /// Minimum audio level to consider as speech (0.0 to 1.0)
  final double speechThreshold;

  const AudioCaptureConfig({
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.bufferSizeMs = 100,
    this.speechThreshold = 0.01,
  });

  /// Get buffer size in samples
  int get bufferSizeInSamples => (sampleRate * bufferSizeMs * channels) ~/ 1000;

  /// Get buffer size in bytes
  int get bufferSizeInBytes => bufferSizeInSamples * (bitsPerSample ~/ 8);
}
