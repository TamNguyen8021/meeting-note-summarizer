import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/audio/audio_capture_interface.dart';
import '../core/audio/audio_capture_factory.dart';
import '../core/audio/audio_source.dart';
import '../core/audio/audio_chunk.dart';

/// Service for managing audio capture and processing
/// Handles audio source selection, capture control, and audio buffering
class AudioService extends ChangeNotifier {
  late final AudioCaptureInterface _audioCapture;
  final AudioCaptureConfig _config;

  // State
  bool _isInitialized = false;
  bool _isCapturing = false;
  List<AudioSource> _availableSources = [];
  AudioSource? _selectedSource;
  double _currentAudioLevel = 0.0;
  String? _lastError;

  // Streams
  StreamSubscription<AudioChunk>? _audioSubscription;
  StreamSubscription<List<AudioSource>>? _sourcesSubscription;
  StreamSubscription<double>? _levelSubscription;

  // Audio buffer for 1-minute processing intervals
  final List<AudioChunk> _audioBuffer = [];
  Timer? _processingTimer;
  final Duration _processingInterval = const Duration(minutes: 1);

  // Stream controllers for external consumption
  final StreamController<List<AudioChunk>> _audioBufferController =
      StreamController<List<AudioChunk>>.broadcast();

  AudioService({AudioCaptureConfig? config})
      : _config = config ?? const AudioCaptureConfig() {
    _audioCapture = AudioCaptureFactory.createAudioCapture(config: _config);
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  List<AudioSource> get availableSources =>
      List.unmodifiable(_availableSources);
  AudioSource? get selectedSource => _selectedSource;
  double get currentAudioLevel => _currentAudioLevel;
  String? get lastError => _lastError;
  bool get supportsSystemAudio => _audioCapture.supportsSystemAudio;

  /// Stream of audio buffers ready for processing (every 1 minute)
  Stream<List<AudioChunk>> get audioBufferStream =>
      _audioBufferController.stream;

  /// Initialize the audio service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;
      final success = await _audioCapture.initialize();

      if (success) {
        _setupStreams();
        _isInitialized = true;

        // Load available sources
        await refreshAudioSources();

        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to initialize audio capture';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Audio initialization error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Refresh the list of available audio sources
  Future<void> refreshAudioSources() async {
    if (!_isInitialized) return;

    try {
      final sources = await _audioCapture.getAvailableSources();
      _availableSources = sources;

      // Auto-select first available source if none selected
      if (_selectedSource == null && sources.isNotEmpty) {
        await selectAudioSource(sources.first);
      }

      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to refresh audio sources: $e';
      notifyListeners();
    }
  }

  /// Select an audio source for capture
  Future<bool> selectAudioSource(AudioSource source) async {
    if (!_isInitialized) return false;

    try {
      final success = await _audioCapture.selectSource(source);
      if (success) {
        _selectedSource = source;
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to select audio source: ${source.name}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Error selecting audio source: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start audio capture
  Future<bool> startCapture() async {
    if (!_isInitialized || _selectedSource == null || _isCapturing) {
      return false;
    }

    try {
      final success = await _audioCapture.startCapture();
      if (success) {
        _isCapturing = true;
        _clearAudioBuffer();
        _startProcessingTimer();
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to start audio capture';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Error starting audio capture: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stop audio capture
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _audioCapture.stopCapture();
      _isCapturing = false;
      _stopProcessingTimer();

      // Process any remaining audio in buffer
      if (_audioBuffer.isNotEmpty) {
        _processAudioBuffer();
      }

      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Error stopping audio capture: $e';
      notifyListeners();
    }
  }

  /// Pause audio capture
  Future<void> pauseCapture() async {
    if (!_isCapturing) return;

    try {
      await _audioCapture.pauseCapture();
      _stopProcessingTimer();
      _isCapturing = false; // Set capturing state to false when paused
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Error pausing audio capture: $e';
      notifyListeners();
    }
  }

  /// Resume audio capture
  Future<bool> resumeCapture() async {
    try {
      final success = await _audioCapture.resumeCapture();
      if (success) {
        _isCapturing = true; // Set capturing state to true when resumed
        _startProcessingTimer();
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to resume audio capture';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Error resuming audio capture: $e';
      notifyListeners();
      return false;
    }
  }

  /// Set up stream subscriptions
  void _setupStreams() {
    // Audio chunk stream
    _audioSubscription = _audioCapture.audioStream.listen(
      _handleAudioChunk,
      onError: (error) {
        _lastError = 'Audio stream error: $error';
        notifyListeners();
      },
    );

    // Audio sources stream
    _sourcesSubscription = _audioCapture.availableSourcesStream.listen(
      (sources) {
        _availableSources = sources;
        notifyListeners();
      },
    );

    // Audio level stream
    _levelSubscription = _audioCapture.audioLevelStream.listen(
      (level) {
        _currentAudioLevel = level;
        notifyListeners();
      },
    );
  }

  /// Handle incoming audio chunks
  void _handleAudioChunk(AudioChunk chunk) {
    if (!_isCapturing) return;

    // Add to buffer
    _audioBuffer.add(chunk);

    // Remove old chunks to prevent memory issues
    // Keep approximately 5 minutes of audio
    const maxBufferDuration = Duration(minutes: 5);
    final cutoffTime = DateTime.now().subtract(maxBufferDuration);

    _audioBuffer.removeWhere((chunk) => chunk.timestamp.isBefore(cutoffTime));
  }

  /// Start the processing timer for 1-minute intervals
  void _startProcessingTimer() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_processingInterval, (timer) {
      _processAudioBuffer();
    });
  }

  /// Stop the processing timer
  void _stopProcessingTimer() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  /// Process the current audio buffer and emit it for AI processing
  void _processAudioBuffer() {
    if (_audioBuffer.isEmpty) return;

    // Create a copy of the current buffer
    final bufferCopy = List<AudioChunk>.from(_audioBuffer);

    // Emit the buffer for processing
    _audioBufferController.add(bufferCopy);

    // Clear processed audio (keep last 10 seconds for overlap)
    const overlapDuration = Duration(seconds: 10);
    final keepAfter = DateTime.now().subtract(overlapDuration);
    _audioBuffer.removeWhere((chunk) => chunk.timestamp.isBefore(keepAfter));
  }

  /// Clear the audio buffer
  void _clearAudioBuffer() {
    _audioBuffer.clear();
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _sourcesSubscription?.cancel();
    _levelSubscription?.cancel();
    _processingTimer?.cancel();

    _audioCapture.dispose();
    _audioBufferController.close();

    super.dispose();
  }
}
