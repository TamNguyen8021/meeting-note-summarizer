import 'dart:async';
import 'package:flutter/foundation.dart';

import '../audio/audio_chunk.dart';
import 'ai_coordinator.dart';
import 'audio_processing_pipeline.dart';
import 'speech_recognition_interface.dart';
import 'summarization_interface.dart';
import '../../services/audio_service.dart';

/// Enhanced AI service that coordinates all AI operations with intelligent model management
/// Provides real-time processing, adaptive model switching, and comprehensive analytics
class EnhancedAiService extends ChangeNotifier {
  final AiCoordinator _aiCoordinator;
  final AudioProcessingPipeline _processingPipeline;
  final AudioService _audioService;

  // Service state
  bool _isInitialized = false;
  bool _isActive = false;
  String? _lastError;

  // Processing statistics
  int _totalChunksProcessed = 0;
  int _totalSpeechSegments = 0;
  int _totalSummaries = 0;
  DateTime? _sessionStartTime;

  // Audio processing
  StreamSubscription<List<AudioChunk>>? _audioSubscription;

  EnhancedAiService({
    AiCoordinator? aiCoordinator,
    AudioProcessingPipeline? processingPipeline,
    AudioService? audioService,
  })  : _aiCoordinator = aiCoordinator ?? AiCoordinator(),
        _processingPipeline = processingPipeline ??
            AudioProcessingPipeline(
              aiCoordinator: aiCoordinator ?? AiCoordinator(),
            ),
        _audioService = audioService ?? AudioService();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isActive => _isActive;
  String? get lastError => _lastError;

  AiCoordinator get aiCoordinator => _aiCoordinator;
  AudioProcessingPipeline get processingPipeline => _processingPipeline;

  // Processing results
  List<SpeechSegment> get allSpeechSegments =>
      _processingPipeline.speechSegments;
  List<MeetingSummary> get summaries => _processingPipeline.summaries;
  Map<String, String> get speakerNames => _processingPipeline.speakerNames;

  // Configuration
  String get currentSpeechModel => _aiCoordinator.currentSpeechModel;
  String get currentSummaryModel => _aiCoordinator.currentSummaryModel;
  bool get adaptiveModelSwitching => _processingPipeline.adaptiveModelSwitching;

  // Quality metrics
  double get currentSpeechConfidence =>
      _processingPipeline.currentSpeechConfidence;
  double get currentNoiseLevel => _processingPipeline.currentNoiseLevel;
  String get detectedLanguage => _processingPipeline.detectedLanguage;

  /// Initialize the enhanced AI service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;

      // Initialize audio service
      final audioSuccess = await _audioService.initialize();
      if (!audioSuccess) {
        _lastError = 'Failed to initialize audio service';
        return false;
      }

      // Initialize AI coordinator
      final aiSuccess = await _aiCoordinator.initialize();
      if (!aiSuccess) {
        _lastError = 'Failed to initialize AI coordinator';
        return false;
      }

      // Initialize processing pipeline
      final pipelineSuccess = await _processingPipeline.initialize();
      if (!pipelineSuccess) {
        _lastError = 'Failed to initialize processing pipeline';
        return false;
      }

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize enhanced AI service: $e';
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  /// Start AI processing session
  Future<bool> startSession() async {
    if (!_isInitialized || _isActive) return false;

    try {
      // Start audio capture
      final audioStarted = await _audioService.startCapture();
      if (!audioStarted) {
        _lastError = 'Failed to start audio capture';
        return false;
      }

      // Start processing pipeline
      final pipelineStarted = await _processingPipeline.startProcessing();
      if (!pipelineStarted) {
        _lastError = 'Failed to start processing pipeline';
        await _audioService.stopCapture();
        return false;
      }

      // Set up audio stream processing
      _setupAudioProcessing();

      _isActive = true;
      _sessionStartTime = DateTime.now();
      _resetSessionStats();

      notifyListeners();
      debugPrint('Enhanced AI service session started');
      return true;
    } catch (e) {
      _lastError = 'Failed to start AI session: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stop AI processing session
  Future<void> stopSession() async {
    if (!_isActive) return;

    try {
      // Stop audio processing
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      // Stop processing pipeline
      _processingPipeline.stopProcessing();

      // Stop audio capture
      await _audioService.stopCapture();

      _isActive = false;
      notifyListeners();

      debugPrint('Enhanced AI service session stopped');
    } catch (e) {
      _lastError = 'Error stopping AI session: $e';
      debugPrint(_lastError);
    }
  }

  /// Switch speech recognition model
  Future<bool> switchSpeechModel(String modelId) async {
    if (!_isInitialized) {
      _lastError = 'Service not initialized';
      return false;
    }

    return await _aiCoordinator.switchSpeechModel(modelId);
  }

  /// Switch summarization model
  Future<bool> switchSummarizationModel(String modelId) async {
    if (!_isInitialized) {
      _lastError = 'Service not initialized';
      return false;
    }

    return await _aiCoordinator.switchSummarizationModel(modelId);
  }

  /// Set adaptive model switching
  void setAdaptiveModelSwitching(bool enabled) {
    _processingPipeline.setAdaptiveModelSwitching(enabled);
    notifyListeners();
  }

  /// Get recommended models for current device
  Map<String, List<String>> getRecommendedModels() {
    return _aiCoordinator.getRecommendedModels();
  }

  /// Get comprehensive processing statistics
  Map<String, dynamic> getProcessingStats() {
    final pipelineStats = _processingPipeline.getProcessingStats();
    final aiCoordinatorStats = _aiCoordinator.getModelStats();

    return {
      'session': {
        'isActive': _isActive,
        'startTime': _sessionStartTime?.toIso8601String(),
        'duration': _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!).inSeconds
            : 0,
      },
      'processing': {
        'totalChunksProcessed': _totalChunksProcessed,
        'totalSpeechSegments': _totalSpeechSegments,
        'totalSummaries': _totalSummaries,
        ...pipelineStats,
      },
      'models': aiCoordinatorStats,
      'quality': {
        'speechConfidence': currentSpeechConfidence,
        'noiseLevel': currentNoiseLevel,
        'detectedLanguage': detectedLanguage,
      },
    };
  }

  /// Get latest summary for live view
  MeetingSummary? get latestSummary {
    final summaries = _processingPipeline.summaries;
    return summaries.isNotEmpty ? summaries.last : null;
  }

  /// Get all action items from summaries
  List<ActionItem> get allActionItems {
    final allItems = <ActionItem>[];
    for (final summary in _processingPipeline.summaries) {
      allItems.addAll(summary.actionItems);
    }
    return allItems;
  }

  /// Get recent speech segments
  List<SpeechSegment> getRecentSpeechSegments({int count = 10}) {
    final segments = _processingPipeline.speechSegments;
    if (segments.length <= count) {
      return List.from(segments);
    }
    return segments.sublist(segments.length - count);
  }

  /// Get recent summaries
  List<MeetingSummary> getRecentSummaries({int count = 5}) {
    final summaries = _processingPipeline.summaries;
    if (summaries.length <= count) {
      return List.from(summaries);
    }
    return summaries.sublist(summaries.length - count);
  }

  /// Clear session data
  void clearSession() {
    _processingPipeline.clearSession();
    _resetSessionStats();
    notifyListeners();
  }

  /// Setup audio processing stream
  void _setupAudioProcessing() {
    _audioSubscription = _audioService.audioBufferStream.listen(
      (audioChunks) {
        if (_isActive) {
          // Process each chunk in the buffer
          for (final chunk in audioChunks) {
            _processingPipeline.processAudioChunk(chunk);
            _totalChunksProcessed++;
          }

          // Update statistics periodically
          if (_totalChunksProcessed % 10 == 0) {
            _updateSessionStats();
          }
        }
      },
      onError: (error) {
        _lastError = 'Audio processing error: $error';
        debugPrint(_lastError);
        notifyListeners();
      },
    );
  }

  /// Update session statistics
  void _updateSessionStats() {
    _totalSpeechSegments = _processingPipeline.speechSegments.length;
    _totalSummaries = _processingPipeline.summaries.length;
    notifyListeners();
  }

  /// Reset session statistics
  void _resetSessionStats() {
    _totalChunksProcessed = 0;
    _totalSpeechSegments = 0;
    _totalSummaries = 0;
  }

  /// Export session data for analysis
  Map<String, dynamic> exportSessionData() {
    return {
      'metadata': {
        'sessionStart': _sessionStartTime?.toIso8601String(),
        'sessionEnd': DateTime.now().toIso8601String(),
        'totalDuration': _sessionStartTime != null
            ? DateTime.now().difference(_sessionStartTime!).inSeconds
            : 0,
      },
      'speechSegments':
          _processingPipeline.speechSegments.map((s) => s.toJson()).toList(),
      'summaries':
          _processingPipeline.summaries.map((s) => s.toJson()).toList(),
      'speakerNames': _processingPipeline.speakerNames,
      'statistics': getProcessingStats(),
    };
  }

  @override
  void dispose() {
    stopSession();
    _processingPipeline.dispose();
    _aiCoordinator.dispose();
    super.dispose();
  }
}
