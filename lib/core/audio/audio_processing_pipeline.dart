import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'audio_chunk.dart';
import 'audio_visualizer.dart';

/// Advanced audio processing pipeline with sliding window analysis
/// Handles real-time audio segmentation, buffering, and preprocessing
class AudioProcessingPipeline extends ChangeNotifier {
  static const Duration _segmentDuration = Duration(seconds: 60); // 1-minute segments
  static const Duration _overlapDuration = Duration(seconds: 10); // 10-second overlap
  static const Duration _windowSize = Duration(seconds: 5); // 5-second analysis windows
  static const int _sampleRate = 16000;
  static const int _channels = 1;

  // Audio buffers and segments
  final List<AudioChunk> _rawBuffer = [];
  final List<AudioSegment> _processedSegments = [];
  final List<AudioChunk> _currentWindow = [];
  
  // Processing state
  bool _isProcessing = false;
  bool _isInitialized = false;
  int _segmentCounter = 0;
  DateTime? _processingStartTime;
  
  // Stream controllers
  final StreamController<AudioSegment> _segmentController = 
      StreamController<AudioSegment>.broadcast();
  final StreamController<AudioVisualizerData> _visualizerController = 
      StreamController<AudioVisualizerData>.broadcast();
  final StreamController<AudioQualityMetrics> _qualityController = 
      StreamController<AudioQualityMetrics>.broadcast();

  // Audio analysis
  final AudioAnalyzer _analyzer = AudioAnalyzer();
  Timer? _processingTimer;
  
  // Configuration
  final AudioProcessingConfig _config;

  AudioProcessingPipeline({AudioProcessingConfig? config})
      : _config = config ?? const AudioProcessingConfig();

  // Getters
  bool get isProcessing => _isProcessing;
  bool get isInitialized => _isInitialized;
  List<AudioSegment> get processedSegments => List.unmodifiable(_processedSegments);
  Stream<AudioSegment> get segmentStream => _segmentController.stream;
  Stream<AudioVisualizerData> get visualizerStream => _visualizerController.stream;
  Stream<AudioQualityMetrics> get qualityStream => _qualityController.stream;

  /// Initialize the audio processing pipeline
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await _analyzer.initialize();
      _setupProcessingTimer();
      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AudioProcessingPipeline initialization failed: $e');
      return false;
    }
  }

  /// Start processing audio chunks
  Future<void> startProcessing() async {
    if (!_isInitialized) {
      throw StateError('Pipeline not initialized');
    }

    if (_isProcessing) return;

    _isProcessing = true;
    _processingStartTime = DateTime.now();
    _processingTimer?.cancel();
    _setupProcessingTimer();
    
    notifyListeners();
  }

  /// Stop processing and clear buffers
  Future<void> stopProcessing() async {
    _isProcessing = false;
    _processingTimer?.cancel();
    
    // Process any remaining audio in buffer
    if (_rawBuffer.isNotEmpty) {
      await _processCurrentBuffer();
    }
    
    _clearBuffers();
    notifyListeners();
  }

  /// Add audio chunk to processing pipeline
  void addAudioChunk(AudioChunk chunk) {
    if (!_isProcessing) return;

    // Validate audio format
    if (!_isValidAudioChunk(chunk)) {
      debugPrint('Invalid audio chunk format');
      return;
    }

    // Add to raw buffer
    _rawBuffer.add(chunk);
    _currentWindow.add(chunk);

    // Update visualizer with real-time data
    _updateVisualizer(chunk);

    // Analyze audio quality
    _analyzeAudioQuality(chunk);

    // Trim window if too large
    _trimCurrentWindow();
  }

  /// Force processing of current buffer (for manual triggers)
  Future<AudioSegment?> processCurrentBuffer() async {
    if (!_isProcessing || _rawBuffer.isEmpty) return null;

    return await _processCurrentBuffer();
  }

  // Private methods

  void _setupProcessingTimer() {
    _processingTimer = Timer.periodic(_segmentDuration, (timer) {
      if (_isProcessing) {
        _processCurrentBuffer();
      }
    });
  }

  Future<AudioSegment?> _processCurrentBuffer() async {
    if (_rawBuffer.isEmpty) return null;

    try {
      // Create segment from current buffer
      final segment = await _createAudioSegment();
      
      _processedSegments.add(segment);
      _segmentController.add(segment);
      
      // Keep only recent segments in memory
      _trimProcessedSegments();
      
      // Implement sliding window - keep overlap
      _implementSlidingWindow();
      
      return segment;
    } catch (e) {
      debugPrint('Error processing audio buffer: $e');
      return null;
    }
  }

  Future<AudioSegment> _createAudioSegment() async {
    final segmentId = 'segment_${_segmentCounter++}';
    final startTime = _processingStartTime ?? DateTime.now();
    final endTime = DateTime.now();
    
    // Combine all audio chunks into a single buffer
    final combinedAudio = _combineAudioChunks(_rawBuffer);
    
    // Analyze audio properties
    final analysis = await _analyzer.analyzeSegment(combinedAudio);
    
    // Detect speech regions
    final speechRegions = await _analyzer.detectSpeechRegions(
      combinedAudio, 
      _config.speechThreshold,
    );
    
    // Apply audio preprocessing
    final processedAudio = await _preprocessAudio(combinedAudio);

    return AudioSegment(
      id: segmentId,
      startTime: startTime,
      endTime: endTime,
      duration: endTime.difference(startTime),
      audioData: processedAudio,
      sampleRate: _sampleRate,
      channels: _channels,
      speechRegions: speechRegions,
      audioAnalysis: analysis,
      qualityScore: analysis.overallQuality,
    );
  }

  Float32List _combineAudioChunks(List<AudioChunk> chunks) {
    if (chunks.isEmpty) return Float32List(0);

    final totalSamples = chunks.fold<int>(
      0, 
      (sum, chunk) => sum + chunk.sampleCount,
    );
    
    final combined = Float32List(totalSamples);
    int offset = 0;
    
    for (final chunk in chunks) {
      final chunkSamples = chunk.toFloat32Samples();
      combined.setRange(offset, offset + chunkSamples.length, chunkSamples);
      offset += chunkSamples.length;
    }
    
    return combined;
  }

  Future<Float32List> _preprocessAudio(Float32List audio) async {
    // Apply noise reduction
    var processed = await _analyzer.reduceNoise(audio, _config.noiseReductionLevel);
    
    // Normalize audio levels
    processed = _analyzer.normalizeAudio(processed);
    
    // Apply bandpass filter for speech frequencies
    processed = await _analyzer.applyBandpassFilter(
      processed, 
      lowFreq: 80, 
      highFreq: 8000,
    );
    
    return processed;
  }

  void _implementSlidingWindow() {
    if (_rawBuffer.isEmpty) return;

    // Calculate how much audio to keep for overlap
    final overlapSamples = (_overlapDuration.inMilliseconds * _sampleRate / 1000).round();
    final totalSamples = _rawBuffer.fold<int>(0, (sum, chunk) => sum + chunk.sampleCount);
    
    if (totalSamples <= overlapSamples) {
      // Keep all if less than overlap duration
      return;
    }

    // Keep only the last overlap duration worth of audio
    final newBuffer = <AudioChunk>[];
    int samplesKept = 0;
    
    for (int i = _rawBuffer.length - 1; i >= 0; i--) {
      final chunk = _rawBuffer[i];
      newBuffer.insert(0, chunk);
      samplesKept += chunk.sampleCount;
      
      if (samplesKept >= overlapSamples) {
        break;
      }
    }
    
    _rawBuffer.clear();
    _rawBuffer.addAll(newBuffer);
  }

  void _updateVisualizer(AudioChunk chunk) {
    final float32Data = chunk.toFloat32Samples();
    final data = _analyzer.calculateVisualizerData(float32Data);
    _visualizerController.add(data);
  }

  void _analyzeAudioQuality(AudioChunk chunk) {
    final float32Data = chunk.toFloat32Samples();
    final metrics = _analyzer.calculateQualityMetrics(float32Data);
    _qualityController.add(metrics);
  }

  bool _isValidAudioChunk(AudioChunk chunk) {
    return chunk.sampleRate == _sampleRate && 
           chunk.channels == _channels &&
           chunk.data.isNotEmpty;
  }

  void _trimCurrentWindow() {
    final maxWindowSamples = (_windowSize.inMilliseconds * _sampleRate / 1000).round();
    final currentSamples = _currentWindow.fold<int>(0, (sum, chunk) => sum + chunk.sampleCount);
    
    while (currentSamples > maxWindowSamples && _currentWindow.isNotEmpty) {
      _currentWindow.removeAt(0);
    }
  }

  void _trimProcessedSegments() {
    // Keep only last 10 segments in memory
    while (_processedSegments.length > 10) {
      _processedSegments.removeAt(0);
    }
  }

  void _clearBuffers() {
    _rawBuffer.clear();
    _currentWindow.clear();
    _segmentCounter = 0;
    _processingStartTime = null;
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _segmentController.close();
    _visualizerController.close();
    _qualityController.close();
    _analyzer.dispose();
    super.dispose();
  }
}

/// Configuration for audio processing pipeline
class AudioProcessingConfig {
  final double speechThreshold;
  final double noiseReductionLevel;
  final bool enablePreprocessing;
  final bool enableQualityAnalysis;
  final int maxSegmentsInMemory;

  const AudioProcessingConfig({
    this.speechThreshold = 0.1,
    this.noiseReductionLevel = 0.3,
    this.enablePreprocessing = true,
    this.enableQualityAnalysis = true,
    this.maxSegmentsInMemory = 10,
  });
}

/// Represents a processed audio segment ready for AI analysis
class AudioSegment {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final Float32List audioData;
  final int sampleRate;
  final int channels;
  final List<SpeechRegion> speechRegions;
  final AudioAnalysisResult audioAnalysis;
  final double qualityScore;

  const AudioSegment({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.audioData,
    required this.sampleRate,
    required this.channels,
    required this.speechRegions,
    required this.audioAnalysis,
    required this.qualityScore,
  });

  /// Get only the speech portions of this segment
  List<Float32List> getSpeechOnlyAudio() {
    final speechAudio = <Float32List>[];
    
    for (final region in speechRegions) {
      final startSample = (region.startTime.inMilliseconds * sampleRate / 1000).round();
      final endSample = (region.endTime.inMilliseconds * sampleRate / 1000).round();
      
      if (startSample < audioData.length && endSample <= audioData.length) {
        final regionAudio = audioData.sublist(startSample, endSample);
        speechAudio.add(Float32List.fromList(regionAudio));
      }
    }
    
    return speechAudio;
  }

  /// Get the total duration of speech in this segment
  Duration get speechDuration {
    return speechRegions.fold<Duration>(
      Duration.zero,
      (total, region) => total + region.duration,
    );
  }

  /// Calculate speech-to-silence ratio
  double get speechRatio {
    if (duration.inMilliseconds == 0) return 0.0;
    return speechDuration.inMilliseconds / duration.inMilliseconds;
  }
}

/// Represents a region of detected speech within an audio segment
class SpeechRegion {
  final Duration startTime;
  final Duration endTime;
  final double confidence;
  final double averageVolume;

  const SpeechRegion({
    required this.startTime,
    required this.endTime,
    required this.confidence,
    required this.averageVolume,
  });

  Duration get duration => endTime - startTime;
}

/// Audio quality metrics for monitoring and adjustment
class AudioQualityMetrics {
  final double signalToNoiseRatio;
  final double averageVolume;
  final double peakVolume;
  final double zeroCrossingRate;
  final double spectralCentroid;
  final bool isClipping;
  final bool isSilent;
  final DateTime timestamp;

  const AudioQualityMetrics({
    required this.signalToNoiseRatio,
    required this.averageVolume,
    required this.peakVolume,
    required this.zeroCrossingRate,
    required this.spectralCentroid,
    required this.isClipping,
    required this.isSilent,
    required this.timestamp,
  });

  /// Overall quality score (0.0 to 1.0)
  double get qualityScore {
    double score = 0.0;
    
    // SNR contribution (0-40 dB mapped to 0-0.4)
    score += (signalToNoiseRatio.clamp(0, 40) / 40) * 0.4;
    
    // Volume contribution (optimal range -20 to -6 dB)
    final volumeDb = 20 * (averageVolume > 0 ? math.log(averageVolume) / math.ln10 : -60);
    if (volumeDb >= -20 && volumeDb <= -6) {
      score += 0.3;
    } else {
      score += 0.3 * (1 - ((volumeDb + 13).abs() / 13).clamp(0, 1));
    }
    
    // No clipping bonus
    if (!isClipping) score += 0.2;
    
    // Not silent bonus
    if (!isSilent) score += 0.1;
    
    return score.clamp(0.0, 1.0);
  }
}

/// Audio analysis results for a segment
class AudioAnalysisResult {
  final double averageVolume;
  final double peakVolume;
  final double noiseLevel;
  final double fundamentalFrequency;
  final List<double> spectralFeatures;
  final bool hasSpeech;
  final double overallQuality;

  const AudioAnalysisResult({
    required this.averageVolume,
    required this.peakVolume,
    required this.noiseLevel,
    required this.fundamentalFrequency,
    required this.spectralFeatures,
    required this.hasSpeech,
    required this.overallQuality,
  });
}

/// Core audio analysis engine
class AudioAnalyzer {
  bool _isInitialized = false;

  Future<void> initialize() async {
    // Initialize any native audio analysis libraries here
    _isInitialized = true;
  }

  Future<AudioAnalysisResult> analyzeSegment(Float32List audio) async {
    if (!_isInitialized) throw StateError('AudioAnalyzer not initialized');

    // Calculate basic audio statistics
    final avgVolume = _calculateAverageVolume(audio);
    final peakVolume = _calculatePeakVolume(audio);
    final noiseLevel = _estimateNoiseLevel(audio);
    final fundamentalFreq = await _estimateFundamentalFrequency(audio);
    final spectralFeatures = await _extractSpectralFeatures(audio);
    final hasSpeech = avgVolume > 0.01; // Simple speech detection
    
    final quality = _calculateOverallQuality(
      avgVolume, peakVolume, noiseLevel, fundamentalFreq,
    );

    return AudioAnalysisResult(
      averageVolume: avgVolume,
      peakVolume: peakVolume,
      noiseLevel: noiseLevel,
      fundamentalFrequency: fundamentalFreq,
      spectralFeatures: spectralFeatures,
      hasSpeech: hasSpeech,
      overallQuality: quality,
    );
  }

  Future<List<SpeechRegion>> detectSpeechRegions(
    Float32List audio, 
    double threshold,
  ) async {
    final regions = <SpeechRegion>[];
    const windowSize = 1600; // 100ms at 16kHz
    const stepSize = 800; // 50ms step
    
    bool inSpeech = false;
    int speechStart = 0;
    
    for (int i = 0; i < audio.length - windowSize; i += stepSize) {
      final window = audio.sublist(i, i + windowSize);
      final energy = _calculateAverageVolume(window);
      
      if (!inSpeech && energy > threshold) {
        // Speech started
        inSpeech = true;
        speechStart = i;
      } else if (inSpeech && energy <= threshold) {
        // Speech ended
        inSpeech = false;
        final speechEnd = i;
        
        if (speechEnd > speechStart) {
          regions.add(SpeechRegion(
            startTime: Duration(milliseconds: (speechStart * 1000 / 16000).round()),
            endTime: Duration(milliseconds: (speechEnd * 1000 / 16000).round()),
            confidence: 0.8, // Simplified confidence
            averageVolume: energy,
          ));
        }
      }
    }
    
    // Handle case where speech continues to the end
    if (inSpeech) {
      regions.add(SpeechRegion(
        startTime: Duration(milliseconds: (speechStart * 1000 / 16000).round()),
        endTime: Duration(milliseconds: (audio.length * 1000 / 16000).round()),
        confidence: 0.8,
        averageVolume: threshold,
      ));
    }
    
    return regions;
  }

  Future<Float32List> reduceNoise(Float32List audio, double level) async {
    // Simple noise reduction using spectral subtraction
    // In production, this would use more sophisticated algorithms
    final reduced = Float32List.fromList(audio);
    
    for (int i = 0; i < reduced.length; i++) {
      reduced[i] = reduced[i] * (1.0 - level * 0.5);
    }
    
    return reduced;
  }

  Float32List normalizeAudio(Float32List audio) {
    final peak = _calculatePeakVolume(audio);
    if (peak == 0) return audio;
    
    final targetPeak = 0.8;
    final gain = targetPeak / peak;
    
    final normalized = Float32List(audio.length);
    for (int i = 0; i < audio.length; i++) {
      normalized[i] = (audio[i] * gain).clamp(-1.0, 1.0);
    }
    
    return normalized;
  }

  Future<Float32List> applyBandpassFilter(
    Float32List audio, {
    required double lowFreq,
    required double highFreq,
  }) async {
    // Simple bandpass filter implementation
    // In production, use proper DSP library
    return Float32List.fromList(audio); // Placeholder
  }

  AudioVisualizerData calculateVisualizerData(Float32List audio) {
    final volume = _calculateAverageVolume(audio);
    
    // Calculate frequency bins for visualization
    final bins = List<double>.filled(32, 0.0);
    // Simplified frequency analysis
    for (int i = 0; i < bins.length; i++) {
      bins[i] = volume * (0.5 + 0.5 * math.sin(i * 0.2));
    }
    
    return AudioVisualizerData(
      level: volume,
      spectrum: bins,
      peakFrequency: 1000.0, // Placeholder
      isSpeechDetected: volume > 0.1,
      timestamp: DateTime.now(),
    );
  }

  AudioQualityMetrics calculateQualityMetrics(Float32List audio) {
    final avgVolume = _calculateAverageVolume(audio);
    final peakVolume = _calculatePeakVolume(audio);
    final snr = _calculateSNR(audio);
    final zcr = _calculateZeroCrossingRate(audio);
    
    return AudioQualityMetrics(
      signalToNoiseRatio: snr,
      averageVolume: avgVolume,
      peakVolume: peakVolume,
      zeroCrossingRate: zcr,
      spectralCentroid: 1000.0, // Placeholder
      isClipping: peakVolume >= 0.99,
      isSilent: avgVolume < 0.001,
      timestamp: DateTime.now(),
    );
  }

  // Private helper methods

  double _calculateAverageVolume(Float32List audio) {
    if (audio.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in audio) {
      sum += sample.abs();
    }
    return sum / audio.length;
  }

  double _calculatePeakVolume(Float32List audio) {
    if (audio.isEmpty) return 0.0;
    
    double peak = 0.0;
    for (final sample in audio) {
      peak = math.max(peak, sample.abs());
    }
    return peak;
  }

  double _estimateNoiseLevel(Float32List audio) {
    // Estimate noise level using lower percentile of audio energy
    final sortedAmplitudes = audio.map((s) => s.abs()).toList()..sort();
    final percentile10 = (sortedAmplitudes.length * 0.1).round();
    return sortedAmplitudes[percentile10];
  }

  Future<double> _estimateFundamentalFrequency(Float32List audio) async {
    // Simplified pitch detection
    // In production, use autocorrelation or YIN algorithm
    return 200.0; // Placeholder
  }

  Future<List<double>> _extractSpectralFeatures(Float32List audio) async {
    // Extract MFCC or other spectral features
    // Placeholder implementation
    return List.generate(13, (i) => i * 0.1);
  }

  double _calculateOverallQuality(
    double avgVolume,
    double peakVolume,
    double noiseLevel,
    double fundamentalFreq,
  ) {
    double quality = 0.0;
    
    // Volume quality (optimal range)
    if (avgVolume > 0.1 && avgVolume < 0.8) {
      quality += 0.3;
    }
    
    // Dynamic range quality
    if (peakVolume / avgVolume > 2.0 && peakVolume / avgVolume < 10.0) {
      quality += 0.3;
    }
    
    // Noise quality
    if (avgVolume / noiseLevel > 10.0) {
      quality += 0.4;
    }
    
    return quality.clamp(0.0, 1.0);
  }

  double _calculateSNR(Float32List audio) {
    final signal = _calculateAverageVolume(audio);
    final noise = _estimateNoiseLevel(audio);
    
    if (noise == 0) return 60.0; // Maximum SNR
    return 20 * math.log(signal / noise) / math.ln10;
  }

  double _calculateZeroCrossingRate(Float32List audio) {
    if (audio.length < 2) return 0.0;
    
    int crossings = 0;
    for (int i = 1; i < audio.length; i++) {
      if ((audio[i] >= 0) != (audio[i - 1] >= 0)) {
        crossings++;
      }
    }
    
    return crossings / audio.length;
  }

  void dispose() {
    _isInitialized = false;
  }
}
