import 'dart:async';
import 'package:flutter/foundation.dart';

import '../audio/audio_chunk.dart';
import '../audio/audio_visualizer.dart';
import 'ai_coordinator.dart';
import 'speech_recognition_interface.dart';
import 'summarization_interface.dart';

/// Intelligent audio processing pipeline that coordinates:
/// - Real-time audio analysis
/// - Adaptive speech recognition
/// - Smart summarization with context awareness
/// - Speaker identification and tracking
/// - Language detection and switching
class AudioProcessingPipeline extends ChangeNotifier {
  final AiCoordinator _aiCoordinator;
  final AudioVisualizer _visualizer;

  // Processing state
  bool _isActive = false;
  bool _isInitialized = false;
  String? _lastError;

  // Audio buffer management
  final List<AudioChunk> _audioBuffer = [];
  Timer? _processingTimer;
  Timer? _summaryTimer;

  // Processing results
  final List<SpeechSegment> _speechSegments = [];
  final List<MeetingSummary> _summaries = [];
  final Map<String, String> _speakerNames = {}; // Simple speaker name mapping

  // Processing configuration
  static const Duration _speechProcessingInterval = Duration(seconds: 5);
  static const Duration _summaryInterval = Duration(seconds: 30);
  static const int _maxBufferChunks = 300; // ~30 seconds at 100ms chunks

  // Quality monitoring
  final List<ProcessingQualityMetric> _qualityMetrics = [];
  double _currentNoiseLevel = 0.0;
  double _currentSpeechConfidence = 0.0;
  String _detectedLanguage = 'en';

  // Adaptive processing
  bool _adaptiveModelSwitching = true;
  int _lowQualityCount = 0;
  DateTime? _lastModelSwitch;

  AudioProcessingPipeline({
    required AiCoordinator aiCoordinator,
    AudioVisualizer? visualizer,
  })  : _aiCoordinator = aiCoordinator,
        _visualizer = visualizer ?? AudioVisualizer();

  // Getters
  bool get isActive => _isActive;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  List<SpeechSegment> get speechSegments => List.unmodifiable(_speechSegments);
  List<MeetingSummary> get summaries => List.unmodifiable(_summaries);
  Map<String, String> get speakerNames => Map.unmodifiable(_speakerNames);

  double get currentNoiseLevel => _currentNoiseLevel;
  double get currentSpeechConfidence => _currentSpeechConfidence;
  String get detectedLanguage => _detectedLanguage;
  bool get adaptiveModelSwitching => _adaptiveModelSwitching;

  Stream<AudioVisualizerData> get visualizationData => _visualizer.dataStream;

  /// Initialize the processing pipeline
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;

      // Initialize AI coordinator
      final aiSuccess = await _aiCoordinator.initialize();
      if (!aiSuccess) {
        _lastError = 'Failed to initialize AI coordinator';
        return false;
      }

      // Initialize visualizer (if available)
      try {
        // AudioVisualizer doesn't have initialize method, skip for now
      } catch (e) {
        debugPrint('AudioVisualizer initialization skipped: $e');
      }

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize audio processing pipeline: $e';
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  /// Start real-time audio processing
  Future<bool> startProcessing() async {
    if (!_isInitialized || _isActive) return false;

    try {
      _isActive = true;
      _speechSegments.clear();
      _summaries.clear();
      _audioBuffer.clear();
      _qualityMetrics.clear();

      // Start processing timers
      _startProcessingTimers();

      notifyListeners();
      debugPrint('Audio processing pipeline started');
      return true;
    } catch (e) {
      _lastError = 'Failed to start processing: $e';
      _isActive = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop audio processing
  void stopProcessing() {
    if (!_isActive) return;

    _isActive = false;

    // Stop timers
    _processingTimer?.cancel();
    _summaryTimer?.cancel();
    _processingTimer = null;
    _summaryTimer = null;

    // Process remaining buffer
    if (_audioBuffer.isNotEmpty) {
      _processAudioBuffer();
    }

    notifyListeners();
    debugPrint('Audio processing pipeline stopped');
  }

  /// Process incoming audio chunk
  void processAudioChunk(AudioChunk chunk) {
    if (!_isActive || !chunk.hasValidData) return;

    // Add to buffer
    _audioBuffer.add(chunk);

    // Update visualization (if available)
    try {
      // AudioVisualizer doesn't have updateVisualization method, skip for now
    } catch (e) {
      debugPrint('AudioVisualizer update skipped: $e');
    }

    // Monitor audio quality
    _updateQualityMetrics(chunk);

    // Manage buffer size
    if (_audioBuffer.length > _maxBufferChunks) {
      _audioBuffer.removeAt(0);
    }

    notifyListeners();
  }

  /// Start processing timers
  void _startProcessingTimers() {
    // Speech recognition timer
    _processingTimer = Timer.periodic(_speechProcessingInterval, (timer) {
      if (_isActive) {
        _processAudioBuffer();
      }
    });

    // Summarization timer
    _summaryTimer = Timer.periodic(_summaryInterval, (timer) {
      if (_isActive) {
        _generateSummary();
      }
    });
  }

  /// Process accumulated audio buffer
  Future<void> _processAudioBuffer() async {
    if (_audioBuffer.isEmpty || _aiCoordinator.speechRecognition == null) {
      return;
    }

    try {
      // Extract audio data from buffer
      final audioData = <Float32List>[];
      DateTime? batchStartTime;

      for (final chunk in _audioBuffer) {
        if (chunk.hasValidData) {
          audioData.add(chunk.toFloat32Samples());
          batchStartTime ??= chunk.timestamp;
        }
      }

      if (audioData.isEmpty) return;

      // Process with speech recognition
      final speechRecognition = _aiCoordinator.speechRecognition!;
      final segments = await speechRecognition.processBatch(
        audioData,
        sampleRate: 16000,
        startTime: batchStartTime,
      );

      if (segments.isNotEmpty) {
        _speechSegments.addAll(segments);

        // Update speaker names (simple tracking)
        await _updateSpeakerNames(segments, audioData);

        // Update language detection
        _updateLanguageDetection(segments);

        // Evaluate processing quality
        _evaluateProcessingQuality(segments);

        // Adaptive model switching if needed
        if (_adaptiveModelSwitching) {
          await _evaluateModelSwitching();
        }

        notifyListeners();

        debugPrint('Processed ${segments.length} speech segments');
      }
    } catch (e) {
      _lastError = 'Error processing audio buffer: $e';
      debugPrint(_lastError);
    }
  }

  /// Generate summary from recent speech segments
  Future<void> _generateSummary() async {
    if (_speechSegments.isEmpty || _aiCoordinator.summarization == null) {
      return;
    }

    try {
      final summarization = _aiCoordinator.summarization!;

      // Take recent segments for summarization
      const maxSegmentsForSummary = 20;
      final segmentsToSummarize = _speechSegments.length > maxSegmentsForSummary
          ? _speechSegments
              .sublist(_speechSegments.length - maxSegmentsForSummary)
          : _speechSegments;

      final summary = await summarization.generateIncrementalSummary(
        _summaries,
        segmentsToSummarize,
      );

      if (summary.hasContent) {
        _summaries.add(summary);
        notifyListeners();

        debugPrint('Generated summary: ${summary.topic}');
      }
    } catch (e) {
      _lastError = 'Error generating summary: $e';
      debugPrint(_lastError);
    }
  }

  /// Update speaker names with new audio data
  Future<void> _updateSpeakerNames(
    List<SpeechSegment> segments,
    List<Float32List> audioData,
  ) async {
    final speechRecognition = _aiCoordinator.speechRecognition;
    if (speechRecognition == null) return;

    for (int i = 0; i < segments.length && i < audioData.length; i++) {
      final segment = segments[i];
      final audio = audioData[i];

      // Update speaker profile in speech recognition
      await speechRecognition.updateSpeakerProfile(segment.speakerId, audio);

      // Track speaker names
      if (!_speakerNames.containsKey(segment.speakerId)) {
        _speakerNames[segment.speakerId] =
            segment.speakerName ?? 'Speaker ${segment.speakerId}';
      }
    }
  }

  /// Update language detection from speech segments
  void _updateLanguageDetection(List<SpeechSegment> segments) {
    if (segments.isEmpty) return;

    final languageCounts = <String, int>{};
    for (final segment in segments) {
      languageCounts[segment.language] =
          (languageCounts[segment.language] ?? 0) + 1;
    }

    final mostCommonLanguage =
        languageCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    if (mostCommonLanguage != _detectedLanguage) {
      _detectedLanguage = mostCommonLanguage;
      debugPrint('Language switched to: $_detectedLanguage');
    }
  }

  /// Update quality metrics from audio chunk
  void _updateQualityMetrics(AudioChunk chunk) {
    // Calculate noise level
    final samples = chunk.toFloat32Samples();
    double sum = 0.0;
    for (final sample in samples) {
      sum += sample.abs();
    }
    _currentNoiseLevel = sum / samples.length;
  }

  /// Evaluate processing quality from speech segments
  void _evaluateProcessingQuality(List<SpeechSegment> segments) {
    if (segments.isEmpty) return;

    // Calculate average confidence
    final avgConfidence =
        segments.map((s) => s.confidence).reduce((a, b) => a + b) /
            segments.length;

    _currentSpeechConfidence = avgConfidence;

    // Record quality metric
    final metric = ProcessingQualityMetric(
      timestamp: DateTime.now(),
      speechConfidence: avgConfidence,
      noiseLevel: _currentNoiseLevel,
      segmentCount: segments.length,
      language: _detectedLanguage,
    );

    _qualityMetrics.add(metric);

    // Keep only recent metrics
    if (_qualityMetrics.length > 100) {
      _qualityMetrics.removeAt(0);
    }

    // Track low quality periods
    if (avgConfidence < 0.6) {
      _lowQualityCount++;
    } else {
      _lowQualityCount = 0;
    }
  }

  /// Evaluate whether to switch models for better quality
  Future<void> _evaluateModelSwitching() async {
    // Don't switch too frequently
    if (_lastModelSwitch != null &&
        DateTime.now().difference(_lastModelSwitch!) <
            const Duration(minutes: 2)) {
      return;
    }

    // Switch if quality is consistently low
    if (_lowQualityCount >= 3) {
      await _tryImproveQuality();
    }
  }

  /// Try to improve processing quality by switching models
  Future<void> _tryImproveQuality() async {
    debugPrint('Attempting to improve processing quality...');

    // Try switching to a better speech model
    final currentSpeechModel = _aiCoordinator.currentSpeechModel;
    String? betterModel;

    if (currentSpeechModel == 'whisper-tiny') {
      betterModel = 'whisper-base';
    } else if (currentSpeechModel == 'whisper-base') {
      betterModel = 'whisper-small';
    }

    if (betterModel != null) {
      final switchSuccess = await _aiCoordinator.switchSpeechModel(betterModel);
      if (switchSuccess) {
        _lastModelSwitch = DateTime.now();
        _lowQualityCount = 0;
        debugPrint('Switched to better speech model: $betterModel');
      }
    }
  }

  /// Get processing statistics
  Map<String, dynamic> getProcessingStats() {
    return {
      'isActive': _isActive,
      'speechSegments': _speechSegments.length,
      'summaries': _summaries.length,
      'speakerNames': _speakerNames.length,
      'bufferSize': _audioBuffer.length,
      'currentNoiseLevel': _currentNoiseLevel,
      'currentSpeechConfidence': _currentSpeechConfidence,
      'detectedLanguage': _detectedLanguage,
      'qualityMetrics': _qualityMetrics.length,
      'lowQualityCount': _lowQualityCount,
      'adaptiveModelSwitching': _adaptiveModelSwitching,
    };
  }

  /// Set adaptive model switching
  void setAdaptiveModelSwitching(bool enabled) {
    _adaptiveModelSwitching = enabled;
    notifyListeners();
  }

  /// Clear all data (for new session)
  void clearSession() {
    _speechSegments.clear();
    _summaries.clear();
    _speakerNames.clear();
    _audioBuffer.clear();
    _qualityMetrics.clear();
    _lowQualityCount = 0;
    _lastModelSwitch = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopProcessing();
    _visualizer.dispose();
    _audioBuffer.clear();
    super.dispose();
  }
}

/// Quality metric for processing evaluation
class ProcessingQualityMetric {
  final DateTime timestamp;
  final double speechConfidence;
  final double noiseLevel;
  final int segmentCount;
  final String language;

  const ProcessingQualityMetric({
    required this.timestamp,
    required this.speechConfidence,
    required this.noiseLevel,
    required this.segmentCount,
    required this.language,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'speechConfidence': speechConfidence,
      'noiseLevel': noiseLevel,
      'segmentCount': segmentCount,
      'language': language,
    };
  }
}
