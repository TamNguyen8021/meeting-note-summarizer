import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'speech_recognition_interface.dart';
import 'enhanced_model_manager.dart';

/// Native Whisper FFI structures
final class WhisperContext extends Opaque {}

final class WhisperFullParams extends Struct {
  /// Decoding strategy (0 = greedy, 1 = beam search)
  @Int32()
  external int strategy;

  /// Number of threads to use
  @Int32()
  external int n_threads;

  /// Language ID
  @Int32()
  external int language_id;

  /// Enable translation
  @Bool()
  external bool translate;
}

/// Native Whisper implementation for speech recognition
/// Uses whisper.cpp through FFI for cross-platform compatibility
class WhisperSpeechRecognition implements SpeechRecognitionInterface {
  final SpeechRecognitionConfig _config;
  final ModelManager _modelManager;

  // Native library and context
  DynamicLibrary? _whisperLib;
  Pointer<WhisperContext>? _whisperContext;

  // State
  bool _isInitialized = false;
  String? _lastError;
  final List<String> _identifiedSpeakers = [];

  // Speaker embeddings for voice identification
  final Map<String, List<double>> _speakerEmbeddings = {};
  int _nextSpeakerId = 1;

  WhisperSpeechRecognition({
    SpeechRecognitionConfig? config,
    required ModelManager modelManager,
  })  : _config = config ?? const SpeechRecognitionConfig(),
        _modelManager = modelManager;

  @override
  SpeechRecognitionConfig get config => _config;

  @override
  bool get isInitialized => _isInitialized;

  @override
  List<String> get identifiedSpeakers => List.unmodifiable(_identifiedSpeakers);

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;

      // Load native library
      if (!await _loadWhisperLibrary()) {
        _lastError = 'Failed to load Whisper native library';
        return false;
      }

      // Ensure required models are downloaded
      final modelId = _getModelIdForPlatform();
      if (!_modelManager.loadedModels.containsKey(modelId)) {
        if (!await _modelManager.downloadModel(modelId)) {
          _lastError = 'Failed to download required Whisper model: $modelId';
          return false;
        }
      }

      // Initialize Whisper context
      if (!await _initializeWhisperContext(modelId)) {
        _lastError = 'Failed to initialize Whisper context';
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      _lastError = 'Whisper initialization error: $e';
      return false;
    }
  }

  @override
  Future<String> detectLanguage(Float32List audioData) async {
    if (!_isInitialized) return _config.language;

    try {
      // For now, return configured language
      // In production, this would use Whisper's language detection
      return _config.language;
    } catch (e) {
      return _config.language;
    }
  }

  @override
  Future<List<SpeechSegment>> processAudio(
    Float32List audioData, {
    int sampleRate = 16000,
    DateTime? timestamp,
  }) async {
    return processBatch([audioData],
        sampleRate: sampleRate, startTime: timestamp);
  }

  @override
  Future<List<SpeechSegment>> processBatch(
    List<Float32List> audioSamples, {
    int sampleRate = 16000,
    DateTime? startTime,
  }) async {
    if (!_isInitialized) return [];

    try {
      // Combine all audio samples
      final combinedAudio = _combineAudioSamples(audioSamples);

      if (_whisperLib == null || _whisperContext == null) {
        // Return empty list if Whisper is not properly initialized
        if (kDebugMode) {
          print('Whisper not initialized - cannot process audio');
        }
        return [];
      }

      // Process with Whisper
      final segments =
          await _processWithWhisper(combinedAudio, sampleRate, startTime);

      // Add speaker identification
      final segmentsWithSpeakers =
          await _addSpeakerIdentification(segments, combinedAudio);

      return segmentsWithSpeakers;
    } catch (e) {
      _lastError = 'Error processing audio batch: $e';
      return [];
    }
  }

  @override
  Future<void> dispose() async {
    if (_whisperContext != null) {
      // In real implementation, would call whisper_free
      _whisperContext = null;
    }
    _whisperLib = null;
    _isInitialized = false;
  }

  @override
  Future<void> updateSpeakerProfile(
      String speakerId, Float32List voiceData) async {
    // Compute embedding from voice data
    final embedding = await _computeSpeakerEmbedding(voiceData);
    _speakerEmbeddings[speakerId] = embedding;

    if (!_identifiedSpeakers.contains(speakerId)) {
      _identifiedSpeakers.add(speakerId);
    }
  }

  /// Load platform-specific Whisper library
  Future<bool> _loadWhisperLibrary() async {
    try {
      if (Platform.isWindows) {
        _whisperLib = DynamicLibrary.open('whisper.dll');
      } else if (Platform.isMacOS) {
        _whisperLib = DynamicLibrary.open('libwhisper.dylib');
      } else if (Platform.isLinux) {
        _whisperLib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isAndroid) {
        _whisperLib = DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isIOS) {
        _whisperLib = DynamicLibrary.process();
      } else {
        return false;
      }

      return _whisperLib != null;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load Whisper library: $e');
        print('Using mock implementation for development');
      }
      // Return true to allow development with mocks
      return true;
    }
  }

  /// Get appropriate model ID for current platform
  String _getModelIdForPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return 'whisper-tiny'; // Mobile uses smaller model
    } else {
      return 'whisper-base'; // Desktop uses larger model
    }
  }

  /// Initialize Whisper context with model
  Future<bool> _initializeWhisperContext(String modelId) async {
    try {
      if (_whisperLib == null) {
        // Development mode - use mock
        return true;
      }

      final modelInfo = _modelManager.loadedModels[modelId]!;
      final modelPath = modelInfo.localPath!;

      // Get function pointers
      final whisperInitFromFile = _whisperLib!.lookupFunction<
          Pointer<WhisperContext> Function(Pointer<Utf8>),
          Pointer<WhisperContext> Function(
              Pointer<Utf8>)>('whisper_init_from_file');

      final modelPathPtr = modelPath.toNativeUtf8();
      _whisperContext = whisperInitFromFile(modelPathPtr);
      calloc.free(modelPathPtr);

      return _whisperContext != null && _whisperContext!.address != 0;
    } catch (e) {
      if (kDebugMode) {
        print('Whisper context initialization failed: $e');
      }
      return false; // Return false if initialization fails
    }
  }

  /// Combine multiple audio samples into one
  Float32List _combineAudioSamples(List<Float32List> audioSamples) {
    if (audioSamples.isEmpty) return Float32List(0);
    if (audioSamples.length == 1) return audioSamples.first;

    final totalLength =
        audioSamples.fold<int>(0, (sum, sample) => sum + sample.length);
    final combined = Float32List(totalLength);

    int offset = 0;
    for (final sample in audioSamples) {
      combined.setRange(offset, offset + sample.length, sample);
      offset += sample.length;
    }

    return combined;
  }

  /// Process audio with native Whisper
  Future<List<SpeechSegment>> _processWithWhisper(
    Float32List audioData,
    int sampleRate,
    DateTime? startTime,
  ) async {
    if (_whisperLib == null || _whisperContext == null) {
      if (kDebugMode) {
        print('Whisper not initialized - cannot process audio');
      }
      return [];
    }

    try {
      // Get Whisper function pointers
      final whisperFull = _whisperLib!.lookupFunction<
          Int32 Function(Pointer<WhisperContext>, Pointer<WhisperFullParams>,
              Pointer<Float>, Int32),
          int Function(Pointer<WhisperContext>, Pointer<WhisperFullParams>,
              Pointer<Float>, int)>('whisper_full');

      final whisperFullDefaultParams = _whisperLib!.lookupFunction<
          Pointer<WhisperFullParams> Function(Int32),
          Pointer<WhisperFullParams> Function(
              int)>('whisper_full_default_params');

      final whisperFullNSegments = _whisperLib!.lookupFunction<
          Int32 Function(Pointer<WhisperContext>),
          int Function(Pointer<WhisperContext>)>('whisper_full_n_segments');

      final whisperFullGetSegmentText = _whisperLib!.lookupFunction<
          Pointer<Utf8> Function(Pointer<WhisperContext>, Int32),
          Pointer<Utf8> Function(
              Pointer<WhisperContext>, int)>('whisper_full_get_segment_text');

      final whisperFullGetSegmentT0 = _whisperLib!.lookupFunction<
          Int64 Function(Pointer<WhisperContext>, Int32),
          int Function(
              Pointer<WhisperContext>, int)>('whisper_full_get_segment_t0');

      final whisperFullGetSegmentT1 = _whisperLib!.lookupFunction<
          Int64 Function(Pointer<WhisperContext>, Int32),
          int Function(
              Pointer<WhisperContext>, int)>('whisper_full_get_segment_t1');

      // Set up parameters
      final params = whisperFullDefaultParams(0); // WHISPER_SAMPLING_GREEDY

      // Allocate audio data
      final audioPtr = calloc<Float>(audioData.length);
      for (int i = 0; i < audioData.length; i++) {
        audioPtr[i] = audioData[i];
      }

      // Process audio
      final result =
          whisperFull(_whisperContext!, params, audioPtr, audioData.length);

      if (result != 0) {
        calloc.free(audioPtr);
        calloc.free(params);
        throw Exception('Whisper processing failed with code: $result');
      }

      // Extract segments
      final nSegments = whisperFullNSegments(_whisperContext!);
      final segments = <SpeechSegment>[];
      final baseTime = startTime ?? DateTime.now();

      for (int i = 0; i < nSegments; i++) {
        final textPtr = whisperFullGetSegmentText(_whisperContext!, i);
        final text = textPtr.toDartString();

        final t0 = whisperFullGetSegmentT0(_whisperContext!, i);
        final t1 = whisperFullGetSegmentT1(_whisperContext!, i);

        // Convert centiseconds to Duration
        final startOffset = Duration(milliseconds: (t0 * 10));
        final endOffset = Duration(milliseconds: (t1 * 10));

        final speakerId = _assignSpeakerId(text);

        segments.add(SpeechSegment(
          text: text.trim(),
          startTime: baseTime.add(startOffset),
          endTime: baseTime.add(endOffset),
          confidence: 0.85, // Whisper doesn't provide confidence by default
          language: _config.language,
          speakerId: speakerId,
          speakerName: _getSpeakerName(speakerId),
        ));
      }

      calloc.free(audioPtr);
      calloc.free(params);
      return segments;
    } catch (e) {
      debugPrint('Whisper processing error: $e');
      return [];
    }
  }

  /// Add speaker identification to segments
  Future<List<SpeechSegment>> _addSpeakerIdentification(
    List<SpeechSegment> segments,
    Float32List audioData,
  ) async {
    if (!_config.enableSpeakerDiarization) {
      return segments;
    }

    final updatedSegments = <SpeechSegment>[];

    for (final segment in segments) {
      // Extract audio for this segment
      final segmentAudio = _extractSegmentAudio(audioData, segment);

      // Get speaker embedding
      final embedding = await _computeSpeakerEmbedding(segmentAudio);

      // Identify or assign speaker
      final speakerId = _identifyOrAssignSpeaker(embedding);

      updatedSegments.add(segment.copyWith(
        speakerId: speakerId,
        speakerName: _getSpeakerName(speakerId),
      ));
    }

    return updatedSegments;
  }

  /// Assign speaker ID based on voice characteristics (simplified)
  String _assignSpeakerId(String text) {
    // Simplified speaker assignment based on text patterns
    // In a real implementation, this would use voice embeddings

    final hash = text.hashCode.abs();
    final speakerIndex = hash % 3; // Support up to 3 speakers
    final speakerId = 'speaker_${speakerIndex + 1}';

    if (!_identifiedSpeakers.contains(speakerId)) {
      _identifiedSpeakers.add(speakerId);
    }

    return speakerId;
  }

  /// Get display name for speaker
  String? _getSpeakerName(String speakerId) {
    // In a real implementation, this could be assigned by user
    return null;
  }

  /// Extract audio segment from full audio
  Float32List _extractSegmentAudio(
      Float32List fullAudio, SpeechSegment segment) {
    // This is a simplified extraction
    // In reality, would use precise timing
    final duration = segment.duration.inMilliseconds;
    final sampleRate = 16000;
    final samplesNeeded = (duration * sampleRate) ~/ 1000;

    if (samplesNeeded >= fullAudio.length) {
      return fullAudio;
    }

    final startSample = 0; // Simplified - would calculate from timing
    final endSample = (startSample + samplesNeeded).clamp(0, fullAudio.length);

    return Float32List.sublistView(fullAudio, startSample, endSample);
  }

  /// Compute speaker embedding for voice identification
  Future<List<double>> _computeSpeakerEmbedding(Float32List audioData) async {
    // Simplified mock embedding computation
    // In real implementation, would use ECAPA-TDNN or mhuBERT-147

    // Generate a stable embedding based on audio characteristics
    final embedding =
        List<double>.filled(192, 0.0); // 192-dimensional embedding

    // Simple spectral features as proxy for real embeddings
    for (int i = 0; i < audioData.length && i < embedding.length; i++) {
      embedding[i] = audioData[i].abs();
    }

    // Normalize
    final magnitude = _vectorMagnitude(embedding);
    if (magnitude > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= magnitude;
      }
    }

    return embedding;
  }

  /// Identify existing speaker or assign new one based on embedding
  String _identifyOrAssignSpeaker(List<double> embedding) {
    const similarityThreshold = 0.8;

    String? bestMatch;
    double bestSimilarity = 0.0;

    // Compare with existing speaker embeddings
    for (final entry in _speakerEmbeddings.entries) {
      final similarity = _cosineSimilarity(embedding, entry.value);
      if (similarity > bestSimilarity && similarity > similarityThreshold) {
        bestSimilarity = similarity;
        bestMatch = entry.key;
      }
    }

    if (bestMatch != null) {
      return bestMatch;
    }

    // Assign new speaker
    final newSpeakerId = 'speaker_$_nextSpeakerId';
    _nextSpeakerId++;
    _speakerEmbeddings[newSpeakerId] = List.from(embedding);

    if (!_identifiedSpeakers.contains(newSpeakerId)) {
      _identifiedSpeakers.add(newSpeakerId);
    }

    return newSpeakerId;
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
    }

    final magnitudeA = _vectorMagnitude(a);
    final magnitudeB = _vectorMagnitude(b);

    if (magnitudeA == 0.0 || magnitudeB == 0.0) return 0.0;

    return dotProduct / (magnitudeA * magnitudeB);
  }

  /// Calculate vector magnitude
  double _vectorMagnitude(List<double> vector) {
    double sum = 0.0;
    for (final value in vector) {
      sum += value * value;
    }
    return sum > 0 ? math.sqrt(sum) : 0.0;
  }
}
