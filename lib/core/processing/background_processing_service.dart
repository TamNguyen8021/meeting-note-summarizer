import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

import '../audio/audio_chunk.dart';
import '../ai/speech_recognition_interface.dart';
import '../ai/summarization_interface.dart';

/// Background processing service for AI operations
/// Handles speech recognition and summarization in isolates to prevent UI blocking
class BackgroundProcessingService {
  // Isolate communication
  Isolate? _speechIsolate;
  Isolate? _summaryIsolate;
  SendPort? _speechSendPort;
  SendPort? _summarySendPort;

  // Communication streams
  final StreamController<SpeechSegment> _speechResultController =
      StreamController<SpeechSegment>.broadcast();
  final StreamController<MeetingSummary> _summaryResultController =
      StreamController<MeetingSummary>.broadcast();
  final StreamController<ProcessingError> _errorController =
      StreamController<ProcessingError>.broadcast();

  // Processing queues
  final List<AudioChunk> _speechQueue = [];
  final List<SpeechSegment> _summaryQueue = [];

  // State
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _processingCount = 0;

  /// Stream of speech recognition results
  Stream<SpeechSegment> get speechResults => _speechResultController.stream;

  /// Stream of summarization results
  Stream<MeetingSummary> get summaryResults => _summaryResultController.stream;

  /// Stream of processing errors
  Stream<ProcessingError> get errors => _errorController.stream;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether processing is currently active
  bool get isProcessing => _isProcessing;

  /// Number of items currently being processed
  int get processingCount => _processingCount;

  /// Initialize the background processing service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('Initializing background processing service...');
      await _initializeSpeechIsolate();
      debugPrint('Speech isolate initialized');

      await _initializeSummaryIsolate();
      debugPrint('Summary isolate initialized');

      _isInitialized = true;
      debugPrint('Background processing service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize background processing: $e');
      return false;
    }
  }

  /// Process audio chunk for speech recognition
  void processSpeechRecognition(AudioChunk audioChunk) {
    if (!_isInitialized || _speechSendPort == null) {
      _errorController.add(ProcessingError(
        type: ProcessingErrorType.speechRecognition,
        message: 'Speech recognition isolate not ready',
        timestamp: DateTime.now(),
      ));
      return;
    }

    _speechQueue.add(audioChunk);
    _processingCount++;

    _speechSendPort!.send({
      'type': 'processAudio',
      'audioChunk': audioChunk.toMap(),
      'requestId': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Process speech segments for summarization
  void processSummarization(List<SpeechSegment> segments) {
    if (!_isInitialized || _summarySendPort == null) {
      _errorController.add(ProcessingError(
        type: ProcessingErrorType.summarization,
        message: 'Summarization isolate not ready',
        timestamp: DateTime.now(),
      ));
      return;
    }

    _summaryQueue.addAll(segments);
    _processingCount++;

    _summarySendPort!.send({
      'type': 'generateSummary',
      'segments': segments.map((s) => s.toMap()).toList(),
      'requestId': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Initialize speech recognition isolate
  Future<void> _initializeSpeechIsolate() async {
    final receivePort = ReceivePort();

    _speechIsolate = await Isolate.spawn(
      _speechRecognitionIsolateEntry,
      receivePort.sendPort,
    );

    // Set up communication with proper stream handling
    final completer = Completer<void>();
    bool isReady = false;

    receivePort.listen((message) {
      if (message is Map && message['type'] == 'ready' && !isReady) {
        _speechSendPort = message['sendPort'];
        isReady = true;
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else {
        _handleSpeechMessage(message);
      }
    });

    await completer.future;
  }

  /// Initialize summarization isolate
  Future<void> _initializeSummaryIsolate() async {
    final receivePort = ReceivePort();

    _summaryIsolate = await Isolate.spawn(
      _summarizationIsolateEntry,
      receivePort.sendPort,
    );

    // Set up communication with proper stream handling
    final completer = Completer<void>();
    bool isReady = false;

    receivePort.listen((message) {
      if (message is Map && message['type'] == 'ready' && !isReady) {
        _summarySendPort = message['sendPort'];
        isReady = true;
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else {
        _handleSummaryMessage(message);
      }
    });

    await completer.future;
  }

  /// Handle messages from speech recognition isolate
  void _handleSpeechMessage(dynamic message) {
    if (message is! Map) return;

    switch (message['type']) {
      case 'result':
        final segment = SpeechSegment.fromMap(message['segment']);
        _speechResultController.add(segment);
        _processingCount =
            (_processingCount - 1).clamp(0, double.infinity.toInt());
        break;

      case 'error':
        _errorController.add(ProcessingError(
          type: ProcessingErrorType.speechRecognition,
          message: message['error'] ?? 'Unknown speech recognition error',
          timestamp: DateTime.now(),
        ));
        _processingCount =
            (_processingCount - 1).clamp(0, double.infinity.toInt());
        break;
    }
  }

  /// Handle messages from summarization isolate
  void _handleSummaryMessage(dynamic message) {
    if (message is! Map) return;

    switch (message['type']) {
      case 'result':
        final summary = MeetingSummary.fromMap(message['summary']);
        _summaryResultController.add(summary);
        _processingCount =
            (_processingCount - 1).clamp(0, double.infinity.toInt());
        break;

      case 'error':
        _errorController.add(ProcessingError(
          type: ProcessingErrorType.summarization,
          message: message['error'] ?? 'Unknown summarization error',
          timestamp: DateTime.now(),
        ));
        _processingCount =
            (_processingCount - 1).clamp(0, double.infinity.toInt());
        break;
    }
  }

  /// Clear processing queues
  void clearQueues() {
    _speechQueue.clear();
    _summaryQueue.clear();
    _processingCount = 0;
  }

  /// Dispose the service and clean up isolates
  Future<void> dispose() async {
    if (!_isInitialized) return;

    _isInitialized = false;
    _isProcessing = false;

    debugPrint('Disposing background processing service...');

    // Clean up isolates
    _speechIsolate?.kill();
    _summaryIsolate?.kill();
    _speechIsolate = null;
    _summaryIsolate = null;
    _speechSendPort = null;
    _summarySendPort = null;

    // Close streams
    await _speechResultController.close();
    await _summaryResultController.close();
    await _errorController.close();

    // Clear queues
    clearQueues();

    debugPrint('Background processing service disposed');
  }

  /// Entry point for speech recognition isolate
  static void _speechRecognitionIsolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();

    // Send back the send port for communication
    mainSendPort.send({
      'type': 'ready',
      'sendPort': receivePort.sendPort,
    });

    // Listen for processing requests
    receivePort.listen((message) {
      if (message is! Map) return;

      switch (message['type']) {
        case 'processAudio':
          _processSpeechInIsolate(message, mainSendPort);
          break;
      }
    });
  }

  /// Entry point for summarization isolate
  static void _summarizationIsolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();

    // Send back the send port for communication
    mainSendPort.send({
      'type': 'ready',
      'sendPort': receivePort.sendPort,
    });

    // Listen for processing requests
    receivePort.listen((message) {
      if (message is! Map) return;

      switch (message['type']) {
        case 'generateSummary':
          _processSummaryInIsolate(message, mainSendPort);
          break;
      }
    });
  }

  /// Process speech recognition in isolate
  static void _processSpeechInIsolate(Map message, SendPort mainSendPort) {
    try {
      // Note: In real implementation, would process the audio chunk data
      // final audioChunkMap = message['audioChunk'] as Map<String, dynamic>;

      // Mock speech recognition processing
      // In real implementation, this would call the native Whisper library
      Future.delayed(const Duration(milliseconds: 500), () {
        final mockSegment = SpeechSegment(
          text: 'Mock speech recognition result',
          startTime: DateTime.now().subtract(const Duration(seconds: 1)),
          endTime: DateTime.now(),
          confidence: 0.85,
          speakerId: 'speaker_1',
          language: 'en',
        );

        mainSendPort.send({
          'type': 'result',
          'segment': mockSegment.toMap(),
          'requestId': message['requestId'],
        });
      });
    } catch (e) {
      mainSendPort.send({
        'type': 'error',
        'error': e.toString(),
        'requestId': message['requestId'],
      });
    }
  }

  /// Process summarization in isolate
  static void _processSummaryInIsolate(Map message, SendPort mainSendPort) {
    try {
      // Convert speech segments from maps
      final segmentMaps = List<Map<String, dynamic>>.from(message['segments']);
      final segments =
          segmentMaps.map((map) => SpeechSegment.fromMap(map)).toList();

      // Mock summarization processing
      // In real implementation, this would call the native Llama library
      Future.delayed(const Duration(milliseconds: 1000), () {
        final mockActionItems = [
          ActionItem(
            description: 'Mock action item 1',
            assignee: 'Team Member 1',
            dueDate: DateTime.now().add(const Duration(days: 7)),
            priority: 'medium',
            isCompleted: false,
          ),
          ActionItem(
            description: 'Mock action item 2',
            assignee: 'Team Member 2',
            dueDate: DateTime.now().add(const Duration(days: 3)),
            priority: 'high',
            isCompleted: false,
          ),
        ];

        final mockSummary = MeetingSummary(
          startTime:
              segments.isNotEmpty ? segments.first.startTime : DateTime.now(),
          endTime: segments.isNotEmpty ? segments.last.endTime : DateTime.now(),
          topic: 'Meeting Summary from ${segments.length} segments',
          keyPoints: [
            'Mock key point 1 from conversation analysis',
            'Mock key point 2 with participant insights',
            'Mock action items and decisions made',
          ],
          actionItems: mockActionItems,
          participants: ['Speaker 1', 'Speaker 2'],
          language: 'en',
          confidence: 0.9,
        );

        mainSendPort.send({
          'type': 'result',
          'summary': mockSummary.toMap(),
          'requestId': message['requestId'],
        });
      });
    } catch (e) {
      mainSendPort.send({
        'type': 'error',
        'error': e.toString(),
        'requestId': message['requestId'],
      });
    }
  }
}

/// Processing error information
class ProcessingError {
  final ProcessingErrorType type;
  final String message;
  final DateTime timestamp;

  const ProcessingError({
    required this.type,
    required this.message,
    required this.timestamp,
  });
}

/// Types of processing errors
enum ProcessingErrorType {
  speechRecognition,
  summarization,
  initialization,
  communication,
}
