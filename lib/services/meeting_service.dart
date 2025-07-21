import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/models/meeting_session.dart';
import '../core/enums/recording_state.dart';
import '../core/audio/audio_source.dart';
import '../core/audio/audio_chunk.dart';
import '../core/audio/audio_visualizer.dart';
import '../core/ai/speech_recognition_interface.dart';
import '../core/ai/summarization_interface.dart' as ai_summary;
import '../core/ai/ai_coordinator.dart';
import '../core/processing/realtime_processing_service.dart';
import 'audio_service.dart';
import 'ai_service.dart';

/// Main service that orchestrates the meeting recording and summarization process
/// Coordinates between audio capture, AI processing, and data management
class MeetingService extends ChangeNotifier {
  final AudioService _audioService;
  final AiService _aiService;
  final RealTimeProcessingService _realtimeService;
  final AiCoordinator _aiCoordinator;
  final Uuid _uuid = const Uuid();

  // Current session state
  MeetingSession? _currentSession;
  RecordingState _recordingState = RecordingState.stopped;
  final List<SummarySegment> _liveSegments = [];
  final List<Comment> _sessionComments = [];

  // Stream subscriptions
  StreamSubscription<List<AudioChunk>>? _audioSubscription;

  // Error handling
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastError;

  MeetingService({
    AudioService? audioService,
    AiService? aiService,
    RealTimeProcessingService? realtimeService,
    AiCoordinator? aiCoordinator,
  })  : _audioService = audioService ?? AudioService(),
        _aiService = aiService ?? AiService(),
        _realtimeService = realtimeService ?? RealTimeProcessingService(),
        _aiCoordinator = aiCoordinator ?? AiCoordinator() {
    // Initialize services safely
    _safeInitialize();
  }

  /// Safe initialization that won't throw exceptions
  void _safeInitialize() {
    Future.microtask(() async {
      try {
        await initialize();
      } catch (e) {
        _lastError = 'Failed to initialize: $e';
        notifyListeners();
      }
    });
  }

  // Getters
  MeetingSession? get currentSession => _currentSession;
  RecordingState get recordingState => _recordingState;
  List<SummarySegment> get liveSegments => List.unmodifiable(_liveSegments);
  List<Comment> get sessionComments => List.unmodifiable(_sessionComments);
  String? get lastError => _lastError;
  bool get isInitialized => _isInitialized;

  // Audio service getters
  bool get isAudioInitialized => _audioService.isInitialized;
  bool get isAiInitialized => _aiService.isInitialized;
  bool get isRealtimeInitialized => _realtimeService.isInitialized;
  double get currentAudioLevel => _audioService.currentAudioLevel;
  List<AudioSource> get availableAudioSources => _audioService.availableSources;
  AudioSource? get selectedAudioSource => _audioService.selectedSource;
  bool get supportsSystemAudio => _audioService.supportsSystemAudio;

  // AI service getters
  String get currentLanguage => _aiService.currentLanguage;
  List<String> get identifiedSpeakers => _aiService.identifiedSpeakers;
  bool get isProcessing => _aiService.isProcessing;

  // Real-time processing getters
  Stream<AudioVisualizerData> get audioVisualization =>
      _realtimeService.visualizationData;
  List<SpeechSegment> get recentSpeechSegments =>
      _realtimeService.speechSegments;
  List<ai_summary.MeetingSummary> get recentSummaries =>
      _realtimeService.summaries;
  Map<String, dynamic> get processingStats => _realtimeService.performanceStats;

  /// Initialize the meeting service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) {
      // Wait for current initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;
    try {
      _lastError = null;

      // Initialize audio service
      final audioSuccess = await _audioService.initialize();
      if (!audioSuccess) {
        _lastError = _audioService.lastError ?? 'Failed to initialize audio';
        notifyListeners();
        return false;
      }

      // Initialize AI service
      final aiSuccess = await _aiService.initialize();
      if (!aiSuccess) {
        _lastError = _aiService.lastError ?? 'Failed to initialize AI';
        notifyListeners();
        return false;
      }

      // Initialize AI coordinator for adaptive model switching
      debugPrint('Starting AI coordinator initialization...');
      final coordinatorSuccess = await _aiCoordinator.initialize();
      if (!coordinatorSuccess) {
        debugPrint(
            'AI coordinator initialization failed, continuing with basic AI functionality');
      } else {
        debugPrint('AI coordinator initialized successfully');
        // Enable adaptive model switching based on device capabilities
        debugPrint('Starting adaptive model switching...');
        await _aiCoordinator.enableAdaptiveModelSwitching();
        debugPrint('Adaptive model switching completed');
      }

      // Initialize real-time processing service
      debugPrint('Starting real-time processing service initialization...');
      final realtimeSuccess = await _realtimeService.initialize();
      if (!realtimeSuccess) {
        debugPrint(
            'Real-time processing initialization failed, continuing with basic functionality');
      } else {
        debugPrint('Real-time processing service initialized successfully');
      }

      _isInitialized = true;
      debugPrint('MeetingService initialization completed successfully');

      // Set up audio processing stream
      _setupAudioProcessing();

      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize meeting service: $e';
      debugPrint(_lastError);
      notifyListeners();
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Start a new meeting session
  Future<bool> startMeeting({String? title}) async {
    if (!isAudioInitialized || !isAiInitialized) {
      _lastError = 'Services not initialized';
      notifyListeners();
      return false;
    }

    if (_recordingState != RecordingState.stopped) {
      _lastError = 'Meeting already in progress';
      notifyListeners();
      return false;
    }

    try {
      // Create new session
      _currentSession = MeetingSession(
        id: _uuid.v4(),
        title: title ?? 'Meeting ${DateTime.now().toLocal()}',
        startTime: DateTime.now(),
        segments: [],
        comments: [],
        primaryLanguage: currentLanguage,
        hasCodeSwitching: false,
      );

      // Clear previous data
      _liveSegments.clear();
      _sessionComments.clear();
      _aiService.clearSession();

      // Start audio capture
      final audioStarted = await _audioService.startCapture();
      if (!audioStarted) {
        _lastError = _audioService.lastError ?? 'Failed to start audio capture';
        _currentSession = null;
        notifyListeners();
        return false;
      }

      _recordingState = RecordingState.recording;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Error starting meeting: $e';
      _currentSession = null;
      notifyListeners();
      return false;
    }
  }

  /// Pause the current meeting
  Future<bool> pauseMeeting() async {
    if (_recordingState != RecordingState.recording) {
      return false;
    }

    try {
      await _audioService.pauseCapture();
      _recordingState = RecordingState.paused;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Error pausing meeting: $e';
      notifyListeners();
      return false;
    }
  }

  /// Resume the paused meeting
  Future<bool> resumeMeeting() async {
    if (_recordingState != RecordingState.paused) {
      return false;
    }

    try {
      final resumed = await _audioService.resumeCapture();
      if (resumed) {
        _recordingState = RecordingState.recording;
        notifyListeners();
        return true;
      } else {
        _lastError = _audioService.lastError ?? 'Failed to resume recording';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Error resuming meeting: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stop the current meeting
  Future<bool> stopMeeting() async {
    if (_recordingState == RecordingState.stopped) {
      return true;
    }

    try {
      // Stop audio capture
      await _audioService.stopCapture();

      // Finalize session
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          endTime: DateTime.now(),
          segments: _liveSegments,
          comments: _sessionComments,
          hasCodeSwitching: _detectCodeSwitching(),
        );
      }

      _recordingState = RecordingState.stopped;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Error stopping meeting: $e';
      notifyListeners();
      return false;
    }
  }

  /// Select an audio source
  Future<bool> selectAudioSource(AudioSource source) async {
    final success = await _audioService.selectAudioSource(source);
    if (!success) {
      _lastError = _audioService.lastError;
    }
    notifyListeners();
    return success;
  }

  /// Refresh available audio sources
  Future<void> refreshAudioSources() async {
    await _audioService.refreshAudioSources();
    notifyListeners();
  }

  /// Add a comment to the current session
  void addComment(String content, {String? segmentId}) {
    if (_currentSession == null) return;

    final comment = Comment(
      id: _uuid.v4(),
      content: content,
      timestamp: DateTime.now(),
      segmentId: segmentId,
      isGlobal: segmentId == null,
    );

    _sessionComments.add(comment);
    notifyListeners();
  }

  /// Update an existing comment
  void updateComment(String commentId, String newContent) {
    final index = _sessionComments.indexWhere((c) => c.id == commentId);
    if (index != -1) {
      _sessionComments[index] = _sessionComments[index].copyWith(
        content: newContent,
      );
      notifyListeners();
    }
  }

  /// Delete a comment
  void deleteComment(String commentId) {
    _sessionComments.removeWhere((c) => c.id == commentId);
    notifyListeners();
  }

  /// Get the current meeting duration
  Duration get currentDuration {
    if (_currentSession == null) return Duration.zero;
    final endTime = _currentSession!.endTime ?? DateTime.now();
    return endTime.difference(_currentSession!.startTime);
  }

  /// Set up audio processing stream
  void _setupAudioProcessing() {
    _audioSubscription?.cancel();
    _audioSubscription = _audioService.audioBufferStream.listen(
      _processAudioBuffer,
      onError: (error) {
        _lastError = 'Audio processing error: $error';
        notifyListeners();
      },
    );
  }

  /// Process audio buffer and generate summaries
  Future<void> _processAudioBuffer(List<AudioChunk> audioChunks) async {
    if (_currentSession == null || _recordingState == RecordingState.stopped) {
      return;
    }

    try {
      // Process with AI service
      await _aiService.processAudioBatch(audioChunks);

      // Convert AI summaries to SummarySegments
      _updateLiveSegments();
    } catch (e) {
      _lastError = 'Error processing audio buffer: $e';
      notifyListeners();
    }
  }

  /// Update live segments from AI summaries
  void _updateLiveSegments() {
    final aiSummaries = _aiService.summaries;
    final speechSegments = _aiService.allSpeechSegments;

    _liveSegments.clear();

    for (int i = 0; i < aiSummaries.length; i++) {
      final aiSummary = aiSummaries[i];

      // Convert AI summary to SummarySegment
      final segment = _convertAiSummaryToSegment(aiSummary, speechSegments);
      _liveSegments.add(segment);
    }

    notifyListeners();
  }

  /// Convert AI MeetingSummary to SummarySegment
  SummarySegment _convertAiSummaryToSegment(
    ai_summary.MeetingSummary aiSummary,
    List<SpeechSegment> speechSegments,
  ) {
    // Calculate relative time from session start
    final sessionStart = _currentSession!.startTime;
    final startTime = aiSummary.startTime.difference(sessionStart);
    final endTime = aiSummary.endTime.difference(sessionStart);

    // Extract speakers from speech segments in this time range
    final segmentSpeakers = speechSegments
        .where((s) =>
            s.startTime.isAfter(
                aiSummary.startTime.subtract(const Duration(seconds: 30))) &&
            s.endTime
                .isBefore(aiSummary.endTime.add(const Duration(seconds: 30))))
        .map((s) => Speaker(
              id: s.speakerId,
              name: s.speakerName,
            ))
        .toSet()
        .toList();

    // Convert AI ActionItems to our ActionItems
    final actionItems = aiSummary.actionItems
        .map((aiAction) => ActionItem(
              id: _uuid.v4(),
              description: aiAction.description,
              assignee: aiAction.assignee,
              dueDate: aiAction.dueDate,
              priority: _convertPriority(aiAction.priority),
            ))
        .toList();

    return SummarySegment(
      id: _uuid.v4(),
      startTime: startTime,
      endTime: endTime,
      topic: aiSummary.topic,
      keyPoints: aiSummary.keyPoints,
      actionItems: actionItems,
      speakers: segmentSpeakers,
      languages: [aiSummary.language],
    );
  }

  // Adaptive AI Features

  /// Get current AI model recommendations based on device capabilities
  Future<Map<String, String>> getModelRecommendations() async {
    return await _aiCoordinator.getModelRecommendations();
  }

  /// Check if a specific model can run optimally on this device
  Future<bool> canModelRunOptimally(String modelId) async {
    return await _aiCoordinator.canModelRunOptimally(modelId);
  }

  /// Manually switch speech recognition model
  Future<bool> switchSpeechModel(String modelId) async {
    return await _aiCoordinator.switchSpeechModel(modelId);
  }

  /// Manually switch summarization model
  Future<bool> switchSummarizationModel(String modelId) async {
    return await _aiCoordinator.switchSummarizationModel(modelId);
  }

  /// Get current AI model information
  Map<String, String> get currentAiModels => {
        'speech': _aiCoordinator.currentSpeechModel,
        'summarization': _aiCoordinator.currentSummaryModel,
      };

  /// Get system status including device capabilities and model information
  Future<Map<String, dynamic>> getSystemStatus() async {
    return await _aiCoordinator.getSystemStatus();
  }

  /// Enable/disable adaptive model switching
  Future<bool> enableAdaptiveModels() async {
    return await _aiCoordinator.enableAdaptiveModelSwitching();
  }

  /// Trigger performance-based model adaptation
  Future<void> optimizePerformance() async {
    await _aiCoordinator.performanceBasedAdaptation();
  }

  /// Convert AI priority string to our Priority enum
  Priority _convertPriority(String priorityString) {
    switch (priorityString.toLowerCase()) {
      case 'high':
        return Priority.high;
      case 'urgent':
        return Priority.urgent;
      case 'low':
        return Priority.low;
      default:
        return Priority.medium;
    }
  }

  /// Detect if code-switching occurred in the session
  bool _detectCodeSwitching() {
    final languages =
        _aiService.allSpeechSegments.map((s) => s.language).toSet();
    return languages.length > 1;
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _audioService.dispose();
    _aiService.dispose();
    super.dispose();
  }
}
