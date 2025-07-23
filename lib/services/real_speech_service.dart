import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Real speech recognition service using speech_to_text
class RealSpeechService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;
  String _lastTranscription = '';
  double _confidence = 0.0;
  String? _lastError;

  final List<String> _transcriptionSegments = [];
  Timer? _summaryTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastTranscription => _lastTranscription;
  double get confidence => _confidence;
  String? get lastError => _lastError;
  List<String> get transcriptionSegments =>
      List.unmodifiable(_transcriptionSegments);

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _lastError = error.errorMsg;
          if (kDebugMode) {
            print('Speech recognition error: ${error.errorMsg}');
          }
          notifyListeners();
        },
        onStatus: (status) {
          if (kDebugMode) {
            print('Speech recognition status: $status');
          }
          _isListening = status == 'listening';
          notifyListeners();
        },
      );

      if (_isInitialized) {
        _lastError = null;
        if (kDebugMode) {
          print('Speech recognition initialized successfully');
        }
      } else {
        _lastError = 'Failed to initialize speech recognition';
        if (kDebugMode) {
          print('Speech recognition initialization failed');
        }
      }

      notifyListeners();
      return _isInitialized;
    } catch (e) {
      _lastError = 'Speech recognition initialization error: $e';
      if (kDebugMode) {
        print('Speech recognition initialization error: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Start listening for speech
  Future<bool> startListening() async {
    if (!_isInitialized) {
      _lastError = 'Speech recognition not initialized';
      notifyListeners();
      return false;
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          _lastTranscription = result.recognizedWords;
          _confidence = result.confidence;

          if (kDebugMode) {
            print(
                'Transcription: $_lastTranscription (confidence: ${(_confidence * 100).toStringAsFixed(1)}%)');
          }

          // Add to segments when speech is finalized
          if (result.finalResult && _lastTranscription.isNotEmpty) {
            _transcriptionSegments.add(_lastTranscription);

            // Keep only last 50 segments to avoid memory issues
            if (_transcriptionSegments.length > 50) {
              _transcriptionSegments.removeAt(0);
            }
          }

          notifyListeners();
        },
        listenFor: const Duration(minutes: 60), // Listen for up to 1 hour
        pauseFor:
            const Duration(seconds: 3), // Pause when no speech for 3 seconds
        partialResults: true, // Get partial results while speaking
        localeId: 'en_US', // English locale
        listenMode: ListenMode.confirmation, // Best for meetings
      );

      _lastError = null;
      _startSummaryGeneration();
      return true;
    } catch (e) {
      _lastError = 'Error starting speech recognition: $e';
      if (kDebugMode) {
        print('Error starting speech recognition: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
      _summaryTimer?.cancel();
      _summaryTimer = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Error stopping speech recognition: $e';
      if (kDebugMode) {
        print('Error stopping speech recognition: $e');
      }
      notifyListeners();
    }
  }

  /// Pause listening
  Future<void> pauseListening() async {
    await stopListening();
  }

  /// Resume listening
  Future<bool> resumeListening() async {
    return await startListening();
  }

  /// Start generating summaries from transcriptions
  void _startSummaryGeneration() {
    _summaryTimer?.cancel();
    _summaryTimer = Timer.periodic(
      const Duration(seconds: 10), // Generate summary every 10 seconds
      (timer) {
        if (_transcriptionSegments.isNotEmpty) {
          // This will trigger summary generation in the meeting service
          notifyListeners();
        }
      },
    );
  }

  /// Get recent transcriptions for summary generation
  List<String> getRecentTranscriptions({int lastNSegments = 5}) {
    if (_transcriptionSegments.isEmpty) return [];

    final start = (_transcriptionSegments.length - lastNSegments)
        .clamp(0, _transcriptionSegments.length);
    return _transcriptionSegments.sublist(start);
  }

  /// Get all transcriptions as a single text
  String getAllTranscriptionsAsText() {
    return _transcriptionSegments.join(' ');
  }

  /// Clear all transcription data
  void clearTranscriptions() {
    _transcriptionSegments.clear();
    _lastTranscription = '';
    _confidence = 0.0;
    notifyListeners();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _summaryTimer?.cancel();
    super.dispose();
  }
}
