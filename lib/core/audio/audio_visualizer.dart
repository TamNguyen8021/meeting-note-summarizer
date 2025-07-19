import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'audio_chunk.dart';

/// Audio visualization data for real-time display
class AudioVisualizerData {
  /// Audio level (0.0 to 1.0)
  final double level;

  /// Frequency spectrum data (for waveform visualization)
  final List<double> spectrum;

  /// Peak frequency (for voice activity detection)
  final double peakFrequency;

  /// Is speech detected (simple voice activity detection)
  final bool isSpeechDetected;

  /// Timestamp of this data
  final DateTime timestamp;

  const AudioVisualizerData({
    required this.level,
    required this.spectrum,
    required this.peakFrequency,
    required this.isSpeechDetected,
    required this.timestamp,
  });
}

/// Real-time audio visualizer for meeting interface
/// Provides audio level monitoring and basic voice activity detection
class AudioVisualizer {
  final StreamController<AudioVisualizerData> _dataController =
      StreamController<AudioVisualizerData>.broadcast();

  late StreamSubscription<AudioChunk> _audioSubscription;

  // Configuration
  final int _spectrumBands;
  final double _speechThreshold;
  final int _smoothingWindow;

  // State
  final List<double> _levelHistory = [];
  final List<List<double>> _spectrumHistory = [];
  bool _isActive = false;

  AudioVisualizer({
    int spectrumBands = 32,
    double speechThreshold = 0.1,
    int smoothingWindow = 5,
  })  : _spectrumBands = spectrumBands,
        _speechThreshold = speechThreshold,
        _smoothingWindow = smoothingWindow;

  /// Stream of visualization data
  Stream<AudioVisualizerData> get dataStream => _dataController.stream;

  /// Whether the visualizer is actively processing
  bool get isActive => _isActive;

  /// Start processing audio chunks for visualization
  void startProcessing(Stream<AudioChunk> audioStream) {
    if (_isActive) return;

    _isActive = true;
    _audioSubscription = audioStream.listen(
      _processAudioChunk,
      onError: (error) {
        // Handle audio processing errors gracefully
        _dataController.addError(error);
      },
    );
  }

  /// Stop processing audio chunks
  void stopProcessing() {
    if (!_isActive) return;

    _isActive = false;
    _audioSubscription.cancel();
    _clearHistory();
  }

  /// Process an individual audio chunk
  void _processAudioChunk(AudioChunk chunk) {
    try {
      // Calculate audio level (RMS)
      final level = _calculateAudioLevel(chunk.data);

      // Calculate basic frequency spectrum
      final spectrum = _calculateSpectrum(chunk.data);

      // Find peak frequency
      final peakFreq = _findPeakFrequency(spectrum, chunk.sampleRate);

      // Simple voice activity detection
      final isSpeech = _detectSpeech(level, spectrum);

      // Apply smoothing
      _addToHistory(level, spectrum);
      final smoothedLevel = _getSmoothedLevel();
      final smoothedSpectrum = _getSmoothedSpectrum();

      // Create visualization data
      final data = AudioVisualizerData(
        level: smoothedLevel,
        spectrum: smoothedSpectrum,
        peakFrequency: peakFreq,
        isSpeechDetected: isSpeech,
        timestamp: DateTime.now(),
      );

      _dataController.add(data);
    } catch (e) {
      // Continue processing even if one chunk fails
      _dataController.addError('Audio processing error: $e');
    }
  }

  /// Calculate RMS audio level
  double _calculateAudioLevel(Uint8List audioData) {
    if (audioData.isEmpty) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < audioData.length; i += 2) {
      // Convert bytes to 16-bit signed int
      final sample = (audioData[i + 1] << 8) | audioData[i];
      final normalized = sample / 32768.0; // Normalize to -1.0 to 1.0
      sum += normalized * normalized;
    }

    final rms = sqrt(sum / (audioData.length / 2));
    return rms.clamp(0.0, 1.0);
  }

  /// Calculate basic frequency spectrum using FFT-like approach
  List<double> _calculateSpectrum(Uint8List audioData) {
    final spectrum = List<double>.filled(_spectrumBands, 0.0);

    if (audioData.length < 2) return spectrum;

    // Simple frequency band analysis
    final samplesPerBand = (audioData.length / 2) / _spectrumBands;

    for (int band = 0; band < _spectrumBands; band++) {
      final startIdx = (band * samplesPerBand).floor() * 2;
      final endIdx = ((band + 1) * samplesPerBand).floor() * 2;

      double bandEnergy = 0.0;
      int sampleCount = 0;

      for (int i = startIdx; i < endIdx && i < audioData.length - 1; i += 2) {
        final sample = (audioData[i + 1] << 8) | audioData[i];
        final normalized = sample / 32768.0;
        bandEnergy += normalized.abs();
        sampleCount++;
      }

      spectrum[band] = sampleCount > 0 ? bandEnergy / sampleCount : 0.0;
    }

    return spectrum;
  }

  /// Find peak frequency from spectrum
  double _findPeakFrequency(List<double> spectrum, int sampleRate) {
    if (spectrum.isEmpty) return 0.0;

    int peakBand = 0;
    double peakValue = spectrum[0];

    for (int i = 1; i < spectrum.length; i++) {
      if (spectrum[i] > peakValue) {
        peakValue = spectrum[i];
        peakBand = i;
      }
    }

    // Convert band index to frequency
    final frequencyPerBand = (sampleRate / 2) / spectrum.length;
    return peakBand * frequencyPerBand;
  }

  /// Simple voice activity detection
  bool _detectSpeech(double level, List<double> spectrum) {
    // Basic heuristics for speech detection
    if (level < _speechThreshold) return false;

    // Check for human voice frequency range (80-1000 Hz)
    const voiceFreqStart = 80;
    const voiceFreqEnd = 1000;

    // Rough estimation: check energy in voice frequency bands
    final voiceBandStart = (voiceFreqStart / (8000 / spectrum.length)).floor();
    final voiceBandEnd = (voiceFreqEnd / (8000 / spectrum.length)).floor();

    double voiceEnergy = 0.0;
    double totalEnergy = 0.0;

    for (int i = 0; i < spectrum.length; i++) {
      totalEnergy += spectrum[i];
      if (i >= voiceBandStart && i <= voiceBandEnd) {
        voiceEnergy += spectrum[i];
      }
    }

    // Speech if voice frequency bands contain significant energy
    return totalEnergy > 0 && (voiceEnergy / totalEnergy) > 0.3;
  }

  /// Add current values to smoothing history
  void _addToHistory(double level, List<double> spectrum) {
    _levelHistory.add(level);
    _spectrumHistory.add(List.from(spectrum));

    // Keep only recent history
    while (_levelHistory.length > _smoothingWindow) {
      _levelHistory.removeAt(0);
    }
    while (_spectrumHistory.length > _smoothingWindow) {
      _spectrumHistory.removeAt(0);
    }
  }

  /// Get smoothed audio level
  double _getSmoothedLevel() {
    if (_levelHistory.isEmpty) return 0.0;

    final sum = _levelHistory.reduce((a, b) => a + b);
    return sum / _levelHistory.length;
  }

  /// Get smoothed spectrum
  List<double> _getSmoothedSpectrum() {
    if (_spectrumHistory.isEmpty) {
      return List<double>.filled(_spectrumBands, 0.0);
    }

    final smoothed = List<double>.filled(_spectrumBands, 0.0);

    for (int band = 0; band < _spectrumBands; band++) {
      double sum = 0.0;
      for (final spectrum in _spectrumHistory) {
        if (band < spectrum.length) {
          sum += spectrum[band];
        }
      }
      smoothed[band] = sum / _spectrumHistory.length;
    }

    return smoothed;
  }

  /// Clear smoothing history
  void _clearHistory() {
    _levelHistory.clear();
    _spectrumHistory.clear();
  }

  /// Dispose resources
  void dispose() {
    stopProcessing();
    _dataController.close();
  }
}
