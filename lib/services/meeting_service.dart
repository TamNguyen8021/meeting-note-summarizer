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
import '../core/database/database_service.dart';
import 'audio_service.dart';
import 'ai_service.dart';
import 'real_speech_service.dart';

/// Main service that orchestrates the meeting recording and summarization process
/// Coordinates between audio capture, AI processing, and data management
class MeetingService extends ChangeNotifier {
  final AudioService _audioService;
  final AiService _aiService;
  final RealTimeProcessingService _realtimeService;
  final AiCoordinator _aiCoordinator;
  final RealSpeechService _speechService;
  final DatabaseService _databaseService;
  final Uuid _uuid = const Uuid();

  // Current session state
  MeetingSession? _currentSession;
  RecordingState _recordingState = RecordingState.stopped;
  final List<SummarySegment> _liveSegments = [];
  final List<Comment> _sessionComments = [];

  // Stream subscriptions
  StreamSubscription<List<AudioChunk>>? _audioSubscription;
  Timer? _summaryTimer;

  // Error handling
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastError;

  MeetingService({
    AudioService? audioService,
    AiService? aiService,
    RealTimeProcessingService? realtimeService,
    AiCoordinator? aiCoordinator,
    RealSpeechService? speechService,
    DatabaseService? databaseService,
  })  : _audioService = audioService ?? AudioService(),
        _aiService = aiService ?? AiService(),
        _realtimeService = realtimeService ?? RealTimeProcessingService(),
        _aiCoordinator = aiCoordinator ?? AiCoordinator(),
        _speechService = speechService ?? RealSpeechService(),
        _databaseService = databaseService ?? DatabaseService() {
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

  // Database methods for retrieving saved meetings
  Future<List<MeetingSession>> getAllMeetings() async {
    try {
      return await _databaseService.getAllMeetingSessions();
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving meetings: $e');
      }
      return [];
    }
  }

  Future<MeetingSession?> getMeetingById(String id) async {
    try {
      return await _databaseService.loadMeetingSession(id);
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving meeting $id: $e');
      }
      return null;
    }
  }

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

      // Initialize AI service (download models if needed)
      await _ensureRequiredModelsAvailable();
      final aiSuccess = await _aiService.initialize();
      if (!aiSuccess) {
        _lastError = _aiService.lastError ?? 'Failed to initialize AI';
        notifyListeners();
        return false;
      }

      // Initialize real speech recognition service
      debugPrint('Starting speech recognition service initialization...');
      final speechSuccess = await _speechService.initialize();
      if (!speechSuccess) {
        debugPrint(
            'Speech recognition initialization failed, continuing with basic functionality');
        _lastError = _speechService.lastError ??
            'Speech recognition initialization failed';
      } else {
        debugPrint('Speech recognition service initialized successfully');
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
      _speechService.clearTranscriptions();

      // Start audio capture
      final audioStarted = await _audioService.startCapture();
      if (!audioStarted) {
        _lastError = _audioService.lastError ?? 'Failed to start audio capture';
        _currentSession = null;
        notifyListeners();
        return false;
      }

      // Start speech recognition
      final speechStarted = await _speechService.startListening();
      if (!speechStarted) {
        if (kDebugMode) {
          print(
              'Warning: Speech recognition failed to start: ${_speechService.lastError}');
        }
        // Don't fail the entire meeting if speech recognition fails
      }

      _recordingState = RecordingState.recording;
      _lastError = null;

      // Start real-time summary generation timer
      _startSummaryTimer();

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
      await _speechService.pauseListening();
      _summaryTimer?.cancel();
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
        final speechResumed = await _speechService.resumeListening();
        if (!speechResumed && kDebugMode) {
          print(
              'Warning: Speech recognition failed to resume: ${_speechService.lastError}');
        }
        _startSummaryTimer();
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

      // Stop speech recognition
      await _speechService.stopListening();

      // Stop summary timer
      _summaryTimer?.cancel();
      _summaryTimer = null;

      // Finalize session
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          endTime: DateTime.now(),
          segments: _liveSegments,
          comments: _sessionComments,
          hasCodeSwitching: _detectCodeSwitching(),
        );

        // Save session to database
        try {
          await _databaseService.saveMeetingSession(_currentSession!);
          if (kDebugMode) {
            print('Meeting session saved successfully: ${_currentSession!.id}');
          }
        } catch (dbError) {
          if (kDebugMode) {
            print('Failed to save meeting session: $dbError');
          }
          // Don't fail the whole stop operation due to database error
        }
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

  /// Start timer for real-time summary generation
  void _startSummaryTimer() {
    _summaryTimer?.cancel();
    _summaryTimer = Timer.periodic(
      const Duration(
          seconds: 10), // Faster generation for demo (every 10 seconds)
      (timer) {
        if (_recordingState == RecordingState.recording &&
            _currentSession != null) {
          if (kDebugMode) {
            print('Timer triggered: generating real-time summary');
          }
          // Call async method without awaiting to avoid blocking the timer
          _generateRealtimeSummary();
        }
      },
    );
  }

  /// Generate real-time summary using AI services
  Future<void> _generateRealtimeSummary() async {
    if (_currentSession == null) return;

    try {
      // Get recent speech transcriptions from the speech service
      final recentTranscriptions =
          _speechService.getRecentTranscriptions(lastNSegments: 3);

      if (recentTranscriptions.isEmpty) {
        if (kDebugMode) {
          print('No recent transcriptions available for summarization');
        }
        return;
      }

      // Get the latest transcriptions with meaningful content
      final textToSummarize = recentTranscriptions
          .where((text) => text.trim().isNotEmpty)
          .join(' ');

      if (textToSummarize.trim().isEmpty) {
        if (kDebugMode) {
          print('No meaningful text to summarize');
        }
        return;
      }

      // Check if we have any AI summaries from the AI service
      final aiSummaries = _aiService.summaries;

      final now = DateTime.now();
      final sessionStart = _currentSession!.startTime;
      final segmentStart = now.subtract(const Duration(seconds: 10));

      // Create a summary segment from available data
      SummarySegment segment;

      if (aiSummaries.isNotEmpty) {
        // Use the latest AI-generated summary
        final latestSummary = aiSummaries.last;
        segment = SummarySegment(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
          startTime: segmentStart.difference(sessionStart),
          endTime: now.difference(sessionStart),
          keyPoints: latestSummary.keyPoints.isNotEmpty
              ? latestSummary.keyPoints
              : ['Summary: $textToSummarize'],
          actionItems: _convertActionItems(latestSummary.actionItems),
          speakers: _extractSpeakersFromText(textToSummarize),
          topic: latestSummary.topic.isNotEmpty
              ? latestSummary.topic
              : 'Meeting Discussion',
        );
      } else {
        // Create a basic segment from transcribed text
        segment = SummarySegment(
          id: 'transcript_${DateTime.now().millisecondsSinceEpoch}',
          startTime: segmentStart.difference(sessionStart),
          endTime: now.difference(sessionStart),
          keyPoints: [
            'Discussion in progress: ${textToSummarize.length > 100 ? '${textToSummarize.substring(0, 100)}...' : textToSummarize}'
          ],
          actionItems: [],
          speakers: _extractSpeakersFromText(textToSummarize),
          topic: 'Live Transcription',
        );
      }

      _liveSegments.add(segment);

      // Keep only last 10 segments for performance
      if (_liveSegments.length > 10) {
        _liveSegments.removeAt(0);
      }

      if (kDebugMode) {
        print(
            'Added real-time segment: ${segment.topic} with ${segment.keyPoints.length} key points');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error generating real-time summary: $e');
      }
      _lastError = 'Failed to generate summary: $e';
      notifyListeners();
    }
  }

  /// Extract speakers from text (simplified approach)
  List<Speaker> _extractSpeakersFromText(String text) {
    // Get speaker information from the AI service if available
    final identifiedSpeakers = _aiService.identifiedSpeakers;

    if (identifiedSpeakers.isNotEmpty) {
      return identifiedSpeakers.asMap().entries.map((entry) {
        return Speaker(
          id: 'speaker_${entry.key}',
          name: entry.value,
        );
      }).toList();
    }

    // Fallback: create a generic speaker
    return [
      Speaker(id: 'speaker_1', name: 'Speaker'),
    ];
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

  /// Ensure required AI models are downloaded before starting processing
  Future<void> _ensureRequiredModelsAvailable() async {
    try {
      final modelManager = _aiService.modelManager;

      // Load Whisper model from bundled assets
      if (!modelManager.availableModels.containsKey('whisper-tiny') ||
          !modelManager.availableModels['whisper-tiny']!.isDownloaded) {
        if (kDebugMode) {
          print('Loading Whisper model from assets...');
        }
        await modelManager.loadModelFromAssets('whisper-tiny');
      }

      // Load TinyLlama model from bundled assets
      if (!modelManager.availableModels.containsKey('tinyllama-q4') ||
          !modelManager.availableModels['tinyllama-q4']!.isDownloaded) {
        if (kDebugMode) {
          print('Loading TinyLlama model from assets...');
        }
        await modelManager.loadModelFromAssets('tinyllama-q4');
      }

      if (kDebugMode) {
        print('Required AI models are loaded from assets');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading models from assets: $e');
        print('AI service initialization failed, using fallback');
      }
      // Don't fail initialization, just log the error
      // The AI services will use real implementations with proper model loading
    }
  }

  /// Convert AI ActionItems to Meeting ActionItems
  List<ActionItem> _convertActionItems(
      List<ai_summary.ActionItem> aiActionItems) {
    return aiActionItems.asMap().entries.map((entry) {
      final aiItem = entry.value;
      return ActionItem(
        id: 'ai_action_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
        description: aiItem.description,
        assignee: aiItem.assignee,
        dueDate: aiItem.dueDate,
        priority: _convertPriority(aiItem.priority),
      );
    }).toList();
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _summaryTimer?.cancel();
    _audioService.dispose();
    _aiService.dispose();
    super.dispose();
  }
}
