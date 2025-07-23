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

    // Calculate actual audio level to determine if there's speech
    final audioLevel = _calculateAudioLevel(audioData);
    final now = timestamp ?? DateTime.now();

    // Only generate speech segments if there's significant audio
    if (audioData.isEmpty || audioLevel < 0.02) {
      return []; // No speech detected
    }

    // Generate realistic speech segments based on actual audio level
    final segments = <SpeechSegment>[];
    final segmentDuration = Duration(
      milliseconds: (audioData.length / sampleRate * 1000).round(),
    );

    // Higher audio level = more likely to have speech
    final speechProbability = (audioLevel * 10).clamp(0.0, 1.0);

    if (_random.nextDouble() < speechProbability) {
      final speakerId = _speakers[_random.nextInt(_speakers.length)];
      final speakerName = 'Speaker ${speakerId.split('_')[1]}';

      // Generate more realistic text based on audio characteristics
      final text = _generateRealisticText(audioLevel, segmentDuration);

      segments.add(SpeechSegment(
        text: text,
        startTime: now,
        endTime: now.add(segmentDuration),
        confidence: (0.7 + audioLevel * 0.3).clamp(0.0, 1.0),
        language: 'en',
        speakerId: speakerId,
        speakerName: speakerName,
      ));
    }

    return segments;
  }

  /// Generate more realistic text based on audio characteristics
  String _generateRealisticText(double audioLevel, Duration duration) {
    final phrases = <String>[];

    // Short phrases for brief audio
    if (duration.inSeconds < 3) {
      phrases.addAll([
        "Yes, I agree with that point.",
        "That's a good idea.",
        "Let me think about this.",
        "Can you clarify that?",
        "Interesting approach.",
        "I see what you mean.",
      ]);
    }

    // Medium phrases for moderate audio
    if (duration.inSeconds >= 3 && duration.inSeconds < 8) {
      phrases.addAll([
        "I think we should consider the implementation details more carefully.",
        "The current approach has some advantages, but we might face scalability issues.",
        "Let's schedule a follow-up meeting to discuss the technical requirements.",
        "We need to ensure that all stakeholders are aligned on this decision.",
        "The timeline seems reasonable, but we should add some buffer time.",
        "I'd like to hear more opinions before we finalize this approach.",
      ]);
    }

    // Longer phrases for extended audio
    if (duration.inSeconds >= 8) {
      phrases.addAll([
        "Based on my analysis of the current system, I believe we should implement a phased approach that allows us to migrate gradually while maintaining system stability.",
        "The budget considerations are important here, and we need to balance the immediate costs against long-term benefits and maintenance requirements.",
        "From a technical perspective, this solution addresses our core requirements, but we should also consider how it integrates with our existing infrastructure and future roadmap.",
        "I've reviewed the proposal and while the overall direction is sound, I think we need to address some specific concerns about security and data privacy compliance.",
      ]);
    }

    if (phrases.isEmpty) {
      return "Discussion about project requirements and implementation strategy.";
    }

    return phrases[_random.nextInt(phrases.length)];
  }

  /// Calculate RMS audio level from samples
  double _calculateAudioLevel(Float32List audioData) {
    if (audioData.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in audioData) {
      sum += sample * sample;
    }

    return sqrt(sum / audioData.length);
  }

  @override
  Future<List<SpeechSegment>> processBatch(
    List<Float32List> audioChunks, {
    int sampleRate = 16000,
    DateTime? startTime,
  }) async {
    if (!_isInitialized) return [];

    // Process each chunk and combine results
    final allSegments = <SpeechSegment>[];
    DateTime currentTime = startTime ?? DateTime.now();

    for (final chunk in audioChunks) {
      final segments = await processAudio(
        chunk,
        sampleRate: sampleRate,
        timestamp: currentTime,
      );
      allSegments.addAll(segments);

      // Advance time based on chunk duration
      currentTime = currentTime.add(Duration(
        milliseconds: (chunk.length / sampleRate * 1000).round(),
      ));
    }

    return allSegments;
  }

  Future<bool> trainSpeakerProfile(
      String speakerId, List<Float32List> samples) async {
    if (!_isInitialized) return false;

    // Mock training - just add speaker if not exists
    if (!_speakers.contains(speakerId)) {
      _speakers.add(speakerId);
    }

    return true;
  }

  @override
  Future<String> detectLanguage(Float32List audioData) async {
    // Mock language detection - always return English
    return 'en';
  }

  @override
  Future<void> updateSpeakerProfile(
      String speakerId, Float32List voiceData) async {
    // Mock speaker profile update - just add speaker if not exists
    if (!_speakers.contains(speakerId)) {
      _speakers.add(speakerId);
    }
  }

  Future<void> clearSession() async {
    if (!_isInitialized) return;

    // Reset speakers to default
    _speakers.clear();
    _speakers.addAll(['speaker_1', 'speaker_2', 'speaker_3']);
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  /// Get a human-readable name for a speaker ID
  String _getSpeakerName(String speakerId) {
    final parts = speakerId.split('_');
    if (parts.length >= 2) {
      return 'Speaker ${parts[1]}';
    }
    return 'Unknown Speaker';
  }
}
