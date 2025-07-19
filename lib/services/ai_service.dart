import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/audio/audio_chunk.dart';
import '../core/ai/speech_recognition_interface.dart';
import '../core/ai/summarization_interface.dart';
import '../core/ai/model_manager.dart';
import '../core/ai/whisper_speech_recognition.dart';
import '../core/ai/llama_summarization.dart';
import 'mock_speech_recognition.dart';
import 'mock_summarization.dart';

/// Main AI service that coordinates speech recognition and summarization
/// Processes audio chunks and generates meeting summaries
class AiService extends ChangeNotifier {
  late final SpeechRecognitionInterface _speechRecognition;
  late final SummarizationInterface _summarization;
  late final ModelManager _modelManager;

  // State
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _lastError;

  // Processing results
  final List<SpeechSegment> _allSpeechSegments = [];
  final List<MeetingSummary> _summaries = [];
  String _currentLanguage = 'en';

  // Processing queue
  final List<List<AudioChunk>> _processingQueue = [];
  bool _isProcessingQueue = false;

  AiService({
    SpeechRecognitionInterface? speechRecognition,
    SummarizationInterface? summarization,
    ModelManager? modelManager,
    bool useMockImplementations = true, // Default to mocks for development
  }) {
    _modelManager = modelManager ?? ModelManager();

    // Use mocks by default for development, real implementations when ready
    if (useMockImplementations || kDebugMode) {
      _speechRecognition = speechRecognition ?? MockSpeechRecognition();
      _summarization = summarization ?? MockSummarization();
    } else {
      _speechRecognition = speechRecognition ??
          WhisperSpeechRecognition(modelManager: _modelManager);
      _summarization =
          summarization ?? LlamaSummarization(modelManager: _modelManager);
    }

    // Initialize model manager in background (non-blocking)
    _initializeModelManager();
  }

  /// Initialize model manager in background
  void _initializeModelManager() {
    Future.microtask(() async {
      try {
        await _modelManager.initialize();
        debugPrint('Model manager initialized successfully');
      } catch (e) {
        debugPrint('Failed to initialize model manager: $e');
        // Continue with mock implementations
      }

      // Mark as initialized regardless of model manager status
      _isInitialized = true;
      notifyListeners();
    });
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String? get lastError => _lastError;
  String get currentLanguage => _currentLanguage;
  List<SpeechSegment> get allSpeechSegments =>
      List.unmodifiable(_allSpeechSegments);
  List<MeetingSummary> get summaries => List.unmodifiable(_summaries);
  List<String> get identifiedSpeakers => _speechRecognition.identifiedSpeakers;
  ModelManager get modelManager => _modelManager;

  /// Initialize the AI service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;

      // Initialize speech recognition
      final speechSuccess = await _speechRecognition.initialize();
      if (!speechSuccess) {
        _lastError = 'Failed to initialize speech recognition';
        notifyListeners();
        return false;
      }

      // Initialize summarization
      final summarySuccess = await _summarization.initialize();
      if (!summarySuccess) {
        _lastError = 'Failed to initialize summarization';
        notifyListeners();
        return false;
      }

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'AI service initialization error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Process a batch of audio chunks (called every 1 minute)
  Future<void> processAudioBatch(List<AudioChunk> audioChunks) async {
    if (!_isInitialized || audioChunks.isEmpty) return;

    // Add to processing queue
    _processingQueue.add(audioChunks);

    // Start processing if not already running
    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  /// Clear all processing data (for new session)
  void clearSession() {
    _allSpeechSegments.clear();
    _summaries.clear();
    _processingQueue.clear();
    _currentLanguage = 'en';
    _lastError = null;
    notifyListeners();
  }

  /// Get the latest summary for live view
  MeetingSummary? get latestSummary =>
      _summaries.isNotEmpty ? _summaries.last : null;

  /// Get all action items from all summaries
  List<ActionItem> get allActionItems {
    final allItems = <ActionItem>[];
    for (final summary in _summaries) {
      allItems.addAll(summary.actionItems);
    }
    return allItems;
  }

  /// Process the queue of audio batches
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;
    _isProcessing = true;
    notifyListeners();

    try {
      while (_processingQueue.isNotEmpty) {
        final audioChunks = _processingQueue.removeAt(0);
        await _processSingleBatch(audioChunks);
      }
    } catch (e) {
      _lastError = 'Error processing audio queue: $e';
    } finally {
      _isProcessingQueue = false;
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Process a single batch of audio chunks
  Future<void> _processSingleBatch(List<AudioChunk> audioChunks) async {
    try {
      // Convert audio chunks to format for speech recognition
      final audioData = <Float32List>[];
      DateTime? batchStartTime;

      for (final chunk in audioChunks) {
        if (chunk.hasValidData) {
          audioData.add(chunk.toFloat32Samples());
          batchStartTime ??= chunk.timestamp;
        }
      }

      if (audioData.isEmpty) return;

      // Step 1: Speech recognition
      final speechSegments = await _speechRecognition.processBatch(
        audioData,
        sampleRate: 16000,
        startTime: batchStartTime,
      );

      if (speechSegments.isEmpty) return;

      // Update current language based on detected speech
      if (speechSegments.isNotEmpty) {
        _currentLanguage = speechSegments.first.language;
      }

      // Add to all speech segments
      _allSpeechSegments.addAll(speechSegments);

      // Step 2: Generate or update summary
      final newSummary = await _generateSummary(speechSegments);
      if (newSummary.hasContent) {
        _summaries.add(newSummary);
      }

      // Update speaker profiles
      for (final segment in speechSegments) {
        final audioIndex = speechSegments.indexOf(segment);
        if (audioIndex < audioData.length) {
          await _speechRecognition.updateSpeakerProfile(
            segment.speakerId,
            audioData[audioIndex],
          );
        }
      }

      notifyListeners();
    } catch (e) {
      _lastError = 'Error processing audio batch: $e';
      notifyListeners();
    }
  }

  /// Generate summary from new speech segments
  Future<MeetingSummary> _generateSummary(
    List<SpeechSegment> newSegments,
  ) async {
    if (_summaries.isEmpty) {
      // First summary
      return await _summarization.generateSummary(newSegments);
    } else {
      // Check for topic change
      final previousSegments =
          _allSpeechSegments.where((s) => !newSegments.contains(s)).toList();

      final hasTopicChange = await _summarization.detectTopicChange(
        previousSegments,
        newSegments,
      );

      if (hasTopicChange) {
        // Create new summary for new topic
        return await _summarization.generateSummary(newSegments);
      } else {
        // Update existing summary with incremental approach
        return await _summarization.generateIncrementalSummary(
          _summaries,
          newSegments,
        );
      }
    }
  }

  /// Extract action items from text
  Future<List<ActionItem>> extractActionItems(String text) async {
    if (!_isInitialized) return [];

    try {
      return await _summarization.extractActionItems(text);
    } catch (e) {
      _lastError = 'Error extracting action items: $e';
      notifyListeners();
      return [];
    }
  }

  /// Get processing statistics
  Map<String, dynamic> get processingStats {
    return {
      'totalSpeechSegments': _allSpeechSegments.length,
      'totalSummaries': _summaries.length,
      'identifiedSpeakers': identifiedSpeakers.length,
      'currentLanguage': _currentLanguage,
      'queueSize': _processingQueue.length,
      'isProcessing': _isProcessing,
    };
  }

  @override
  void dispose() {
    _speechRecognition.dispose();
    _summarization.dispose();
    super.dispose();
  }
}
