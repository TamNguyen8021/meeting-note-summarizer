import 'dart:typed_data';

/// Represents a chunk of audio data for processing
class AudioChunk {
  /// Raw audio data as 16-bit PCM samples
  final Uint8List data;

  /// Timestamp when this chunk was captured
  final DateTime timestamp;

  /// Duration of the audio chunk
  final Duration duration;

  /// Sample rate in Hz (typically 16000)
  final int sampleRate;

  /// Number of channels (1 for mono, 2 for stereo)
  final int channels;

  /// Bits per sample (typically 16)
  final int bitsPerSample;

  /// Audio level (0.0 to 1.0) for visualization
  final double level;

  const AudioChunk({
    required this.data,
    required this.timestamp,
    required this.duration,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.level,
  });

  /// Get the number of samples in this chunk
  int get sampleCount => data.length ~/ (bitsPerSample ~/ 8) ~/ channels;

  /// Get the size in bytes
  int get sizeInBytes => data.length;

  /// Check if this chunk has valid audio data
  bool get hasValidData => data.isNotEmpty && level > 0.0;

  /// Convert to a format suitable for AI processing
  /// Returns normalized float32 samples (-1.0 to 1.0)
  Float32List toFloat32Samples() {
    final samples = Float32List(sampleCount);
    final bytesPerSample = bitsPerSample ~/ 8;

    for (int i = 0; i < sampleCount; i++) {
      int sampleValue = 0;

      // Convert little-endian bytes to sample value
      for (int b = 0; b < bytesPerSample; b++) {
        sampleValue |= data[i * bytesPerSample + b] << (b * 8);
      }

      // Convert to signed value and normalize
      if (bitsPerSample == 16) {
        // Convert unsigned to signed 16-bit
        if (sampleValue >= 32768) sampleValue -= 65536;
        samples[i] = sampleValue / 32768.0;
      } else {
        // Handle other bit depths if needed
        samples[i] = (sampleValue - (1 << (bitsPerSample - 1))) /
            (1 << (bitsPerSample - 1));
      }
    }

    return samples;
  }

  @override
  String toString() =>
      'AudioChunk(${duration.inMilliseconds}ms, ${sampleCount} samples, '
      'level: ${(level * 100).toStringAsFixed(1)}%)';
}
