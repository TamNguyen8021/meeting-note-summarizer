import 'dart:typed_data';
import 'dart:math';

import '../core/ai/speech_recognition_interface.dart';

/// Mock implementation of speech recognition for development and testing
/// This will be replaced with actual Whisper integration later
class MockSpeechRecognition implements SpeechRecognitionInterface {
  final SpeechRecognitionConfig _config;
  bool _isInitialized = false;
  final List<String> _speakers = ['speaker_1', 'speaker_2', 'speaker_3'];
  final Random _random = Random();

  MockSpeechRecognition({SpeechRecognitionConfig? config})
      : _config = config ?? const SpeechRecognitionConfig();

  @override
  SpeechRecognitionConfig get config => _config;

  @override
  bool get isInitialized => _isInitialized;

  @override
  List<String> get identifiedSpeakers => List.from(_speakers);

  @override
  Future<bool> initialize() async {
    // Simulate initialization delay
    await Future.delayed(const Duration(milliseconds: 500));
    _isInitialized = true;
    return true;
  }

  @override
  Future<List<SpeechSegment>> processAudio(
    Float32List audioData, {
    int sampleRate = 16000,
    DateTime? timestamp,
  }) async {
    if (!_isInitialized) return [];

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Generate mock speech segments based on audio data
    if (audioData.isEmpty || _calculateAudioLevel(audioData) < 0.01) {
      return []; // No speech detected
    }

    final now = timestamp ?? DateTime.now();
    final duration = Duration(
      milliseconds: (audioData.length * 1000) ~/ sampleRate,
    );

    // Generate mock speech content
    final mockTexts = [
      'Let me start by reviewing our quarterly objectives.',
      'The marketing team has exceeded expectations this quarter.',
      'We need to address the budget allocation for next month.',
      'Sarah, can you provide an update on the client project?',
      'I think we should schedule a follow-up meeting next week.',
      'The development timeline looks good so far.',
      'Any questions or concerns about these numbers?',
      'Let\'s move on to the next agenda item.',
    ];

    final segments = <SpeechSegment>[];
    final numSegments = _random.nextInt(2) + 1; // 1-2 segments

    for (int i = 0; i < numSegments; i++) {
      final segmentStart = now.add(Duration(
        milliseconds: (duration.inMilliseconds * i / numSegments).round(),
      ));
      final segmentEnd = now.add(Duration(
        milliseconds: (duration.inMilliseconds * (i + 1) / numSegments).round(),
      ));

      final speaker = _speakers[_random.nextInt(_speakers.length)];
      final text = mockTexts[_random.nextInt(mockTexts.length)];
      final confidence = 0.7 + _random.nextDouble() * 0.3; // 0.7-1.0

      segments.add(SpeechSegment(
        text: text,
        startTime: segmentStart,
        endTime: segmentEnd,
        confidence: confidence,
        language: _config.language,
        speakerId: speaker,
        speakerName: _getSpeakerName(speaker),
      ));
    }

    return segments;
  }

  @override
  Future<List<SpeechSegment>> processBatch(
    List<Float32List> audioChunks, {
    int sampleRate = 16000,
    DateTime? startTime,
  }) async {
    if (!_isInitialized || audioChunks.isEmpty) return [];

    final allSegments = <SpeechSegment>[];
    final baseTime = startTime ?? DateTime.now();

    for (int i = 0; i < audioChunks.length; i++) {
      final chunkStartTime = baseTime.add(Duration(
        milliseconds: (i * audioChunks[i].length * 1000) ~/ sampleRate,
      ));

      final segments = await processAudio(
        audioChunks[i],
        sampleRate: sampleRate,
        timestamp: chunkStartTime,
      );

      allSegments.addAll(segments);
    }

    return allSegments;
  }

  @override
  Future<String> detectLanguage(Float32List audioData) async {
    if (!_isInitialized) return 'en';

    // Simulate language detection
    await Future.delayed(const Duration(milliseconds: 50));

    // Mock language detection based on config
    if (_config.enableLanguageDetection) {
      // Randomly switch between English and Vietnamese for testing
      return _random.nextBool() ? 'en' : 'vi';
    }

    return _config.language;
  }

  @override
  Future<void> updateSpeakerProfile(
      String speakerId, Float32List voiceData) async {
    if (!_isInitialized) return;

    // Mock speaker profile update
    if (!_speakers.contains(speakerId)) {
      _speakers.add(speakerId);
    }

    // Simulate processing
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  /// Calculate audio level from samples
  double _calculateAudioLevel(Float32List samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample.abs();
    }

    return sum / samples.length;
  }

  /// Get a mock speaker name
  String? _getSpeakerName(String speakerId) {
    switch (speakerId) {
      case 'speaker_1':
        return 'John';
      case 'speaker_2':
        return 'Sarah';
      case 'speaker_3':
        return 'Mike';
      default:
        return null;
    }
  }
}
