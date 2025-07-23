import 'dart:typed_data';
import 'dart:math';

import '../core/ai/speech_recognition_interface.dart';

/// Mock implementation of speech recognition for development and testing
/// This will be replaced with actual Whisper integration later
/// Enhanced to respond to actual audio input levels
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
        "Exactly, that makes sense.",
        "Good point about that.",
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
        "Based on the current data, I think we're on the right track.",
        "We should also consider the impact on our existing systems.",
      ]);
    }

    // Longer phrases for extended audio
    if (duration.inSeconds >= 8) {
      phrases.addAll([
        "Based on my analysis of the current system, I believe we should implement a phased approach that allows us to migrate gradually while maintaining system stability.",
        "The budget considerations are important here, and we need to balance the immediate costs against long-term benefits and maintenance requirements.",
        "From a technical perspective, this solution addresses our core requirements, but we should also consider how it integrates with our existing infrastructure and future roadmap.",
        "I've reviewed the proposal and while the overall direction is sound, I think we need to address some specific concerns about security and data privacy compliance.",
        "Looking at the market trends and user feedback, I believe this feature will significantly improve user experience and help us stay competitive in the market.",
      ]);
    }

    if (phrases.isEmpty) {
      phrases.add(
          "Discussion about project requirements and implementation strategy.");
    }

    return phrases[_random.nextInt(phrases.length)];
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
    if (_config.enableLanguageDetection) {
      // Randomly switch between English and Vietnamese for demo
      return _random.nextBool() ? 'en' : 'vi';
    }
    return _config.language;
  }

  @override
  Future<void> updateSpeakerProfile(
      String speakerId, Float32List voiceData) async {
    if (!_isInitialized) return;

    // In a real implementation, this would update speaker voice characteristics
    // For mock, we just add the speaker if not exists
    if (!_speakers.contains(speakerId)) {
      _speakers.add(speakerId);
    }
  }

  /// Add a new speaker (helper method)
  Future<void> addSpeaker(String speakerId, {String? name}) async {
    if (!_isInitialized) return;

    if (!_speakers.contains(speakerId)) {
      _speakers.add(speakerId);
    }
  }

  /// Remove a speaker (helper method)
  Future<void> removeSpeaker(String speakerId) async {
    if (!_isInitialized) return;
    _speakers.remove(speakerId);
  }

  /// Update configuration (helper method)
  Future<void> updateConfig(SpeechRecognitionConfig newConfig) async {
    // In a real implementation, this would update the underlying model configuration
    // For mock, we just acknowledge the update
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Calculate the average audio level (RMS)
  double _calculateAudioLevel(Float32List audioData) {
    if (audioData.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in audioData) {
      sum += sample * sample;
    }
    return sqrt(sum / audioData.length);
  }

  /// Get display name for a speaker
  String _getSpeakerName(String speakerId) {
    final parts = speakerId.split('_');
    if (parts.length > 1) {
      return 'Speaker ${parts[1]}';
    }
    return speakerId;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }
}
