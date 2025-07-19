import 'dart:async';
import 'package:flutter/foundation.dart';

import '../audio/audio_chunk.dart';
import '../audio/audio_visualizer.dart';
import '../ai/speech_recognition_interface.dart';
import '../ai/summarization_interface.dart';
import 'background_processing_service.dart';

/// Real-time processing coordinator that manages audio visualization,
/// speech recognition, and summarization with proper performance optimization
class RealTimeProcessingService extends ChangeNotifier {
  final BackgroundProcessingService _backgroundService;
  final AudioVisualizer _visualizer;

  // Processing state
  bool _isActive = false;
  bool _isInitialized = false;
  bool _listenersSetup = false;

  // Audio processing
  StreamSubscription<AudioChunk>? _audioSubscription;
  final List<AudioChunk> _audioBuffer = [];
  Timer? _processingTimer;

  // Speech recognition state
  final List<SpeechSegment> _speechSegments = [];
  final List<MeetingSummary> _summaries = [];

  // Processing configuration
  static const Duration _processingInterval =
      Duration(seconds: 30); // Process every 30 seconds
  static const int _maxBufferSize = 100; // Keep last 100 audio chunks

  // Performance monitoring
  int _totalChunksProcessed = 0;
  int _speechSegmentsGenerated = 0;
  int _summariesGenerated = 0;
  DateTime? _lastProcessingTime;

  RealTimeProcessingService({
    BackgroundProcessingService? backgroundService,
    AudioVisualizer? visualizer,
  })  : _backgroundService = backgroundService ?? BackgroundProcessingService(),
        _visualizer = visualizer ?? AudioVisualizer();

  /// Whether the service is initialized and ready
  bool get isInitialized => _isInitialized;

  /// Whether real-time processing is active
  bool get isActive => _isActive;

  /// Current audio visualization data stream
  Stream<AudioVisualizerData> get visualizationData => _visualizer.dataStream;

  /// Current speech segments
  List<SpeechSegment> get speechSegments => List.unmodifiable(_speechSegments);

  /// Current meeting summaries
  List<MeetingSummary> get summaries => List.unmodifiable(_summaries);

  /// Processing performance statistics
  Map<String, dynamic> get performanceStats => {
        'totalChunksProcessed': _totalChunksProcessed,
        'speechSegmentsGenerated': _speechSegmentsGenerated,
        'summariesGenerated': _summariesGenerated,
        'lastProcessingTime': _lastProcessingTime?.toIso8601String(),
        'isBackgroundServiceReady': _backgroundService.isInitialized,
        'currentBufferSize': _audioBuffer.length,
      };

  /// Initialize the real-time processing service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('Initializing real-time processing service...');

      // Initialize background processing service
      if (!await _backgroundService.initialize()) {
        debugPrint('Failed to initialize background processing service');
        return false;
      }

      // Set up background service listeners only once
      if (!_listenersSetup) {
        _setupBackgroundServiceListeners();
        _listenersSetup = true;
      }

      _isInitialized = true;
      debugPrint('Real-time processing service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize real-time processing service: $e');
      return false;
    }
  }

  /// Start real-time processing of audio stream
  void startProcessing(Stream<AudioChunk> audioStream) {
    if (!_isInitialized || _isActive) return;

    _isActive = true;
    debugPrint('Starting real-time audio processing');

    // Start audio visualization
    _visualizer.startProcessing(audioStream);

    // Start audio buffering for speech recognition
    _audioSubscription = audioStream.listen(
      _handleAudioChunk,
      onError: (error) {
        debugPrint('Audio stream error: $error');
        _handleProcessingError(error);
      },
    );

    // Start periodic processing timer
    _processingTimer =
        Timer.periodic(_processingInterval, _performPeriodicProcessing);

    notifyListeners();
  }

  /// Stop real-time processing
  void stopProcessing() {
    if (!_isActive) return;

    _isActive = false;
    debugPrint('Stopping real-time audio processing');

    // Stop visualization
    _visualizer.stopProcessing();

    // Stop audio stream
    _audioSubscription?.cancel();
    _audioSubscription = null;

    // Stop periodic processing
    _processingTimer?.cancel();
    _processingTimer = null;

    // Process any remaining audio
    if (_audioBuffer.isNotEmpty) {
      _processAccumulatedAudio();
    }

    notifyListeners();
  }

  /// Handle incoming audio chunk
  void _handleAudioChunk(AudioChunk chunk) {
    _audioBuffer.add(chunk);
    _totalChunksProcessed++;

    // Maintain buffer size limit
    while (_audioBuffer.length > _maxBufferSize) {
      _audioBuffer.removeAt(0);
    }

    // Process immediately if buffer is getting full
    if (_audioBuffer.length >= _maxBufferSize) {
      _processAccumulatedAudio();
    }
  }

  /// Perform periodic processing (every 30 seconds)
  void _performPeriodicProcessing(Timer timer) {
    if (_audioBuffer.isNotEmpty) {
      _processAccumulatedAudio();
    }

    // Generate summary if enough speech segments have accumulated
    if (_speechSegments.length >= 5) {
      _generateSummary();
    }

    _lastProcessingTime = DateTime.now();
  }

  /// Process accumulated audio for speech recognition
  void _processAccumulatedAudio() {
    if (_audioBuffer.isEmpty) return;

    // Take a copy of current buffer for processing
    final audioToProcess = List<AudioChunk>.from(_audioBuffer);
    _audioBuffer.clear();

    // Send for background processing
    for (final chunk in audioToProcess) {
      _backgroundService.processSpeechRecognition(chunk);
    }

    debugPrint(
        'Sent ${audioToProcess.length} audio chunks for speech recognition');
  }

  /// Generate summary from accumulated speech segments
  void _generateSummary() {
    if (_speechSegments.isEmpty) return;

    // Take recent speech segments for summarization
    const maxSegmentsForSummary = 20;
    final segmentsToSummarize = _speechSegments.length > maxSegmentsForSummary
        ? _speechSegments
            .sublist(_speechSegments.length - maxSegmentsForSummary)
        : _speechSegments;

    // Send for background summarization
    _backgroundService.processSummarization(segmentsToSummarize);

    debugPrint(
        'Sent ${segmentsToSummarize.length} speech segments for summarization');
  }

  /// Set up listeners for background service results
  void _setupBackgroundServiceListeners() {
    // Listen for speech recognition results
    _backgroundService.speechResults.listen(
      (segment) {
        _speechSegments.add(segment);
        _speechSegmentsGenerated++;
        notifyListeners();
        debugPrint(
            'Received speech segment: ${segment.text.substring(0, segment.text.length.clamp(0, 50))}...');
      },
      onError: (error) {
        debugPrint('Speech recognition error: $error');
      },
    );

    // Listen for summarization results
    _backgroundService.summaryResults.listen(
      (summary) {
        _summaries.add(summary);
        _summariesGenerated++;
        notifyListeners();
        debugPrint('Received summary: ${summary.topic}');
      },
      onError: (error) {
        debugPrint('Summarization error: $error');
      },
    );

    // Listen for processing errors
    _backgroundService.errors.listen(
      (error) {
        debugPrint('Background processing error: ${error.message}');
        _handleProcessingError(error);
      },
    );
  }

  /// Handle processing errors
  void _handleProcessingError(dynamic error) {
    // Log error and continue processing
    debugPrint('Processing error handled: $error');
    // Could emit error events or update UI state here
  }

  /// Clear all accumulated data
  void clearData() {
    _speechSegments.clear();
    _summaries.clear();
    _audioBuffer.clear();
    _backgroundService.clearQueues();

    // Reset statistics
    _totalChunksProcessed = 0;
    _speechSegmentsGenerated = 0;
    _summariesGenerated = 0;
    _lastProcessingTime = null;

    notifyListeners();
    debugPrint('All processing data cleared');
  }

  /// Get recent speech segments (last N segments)
  List<SpeechSegment> getRecentSpeechSegments({int count = 10}) {
    if (_speechSegments.length <= count) {
      return List.from(_speechSegments);
    }
    return _speechSegments.sublist(_speechSegments.length - count);
  }

  /// Get recent summaries (last N summaries)
  List<MeetingSummary> getRecentSummaries({int count = 5}) {
    if (_summaries.length <= count) {
      return List.from(_summaries);
    }
    return _summaries.sublist(_summaries.length - count);
  }

  /// Dispose resources
  @override
  void dispose() {
    debugPrint('Disposing real-time processing service...');
    stopProcessing();
    _visualizer.dispose();
    _backgroundService.dispose();
    _listenersSetup = false;
    super.dispose();
    debugPrint('Real-time processing service disposed');
  }
}
