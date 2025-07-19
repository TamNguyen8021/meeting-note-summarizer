import 'dart:typed_data';

/// Configuration for speech recognition processing
class SpeechRecognitionConfig {
  /// Target language for recognition
  final String language;

  /// Enable speaker diarization (identifying different speakers)
  final bool enableSpeakerDiarization;

  /// Enable automatic language detection
  final bool enableLanguageDetection;

  /// Minimum confidence threshold for recognition results
  final double confidenceThreshold;

  /// Support for code-switching between languages
  final bool enableCodeSwitching;

  const SpeechRecognitionConfig({
    this.language = 'en',
    this.enableSpeakerDiarization = true,
    this.enableLanguageDetection = true,
    this.confidenceThreshold = 0.7,
    this.enableCodeSwitching = true,
  });
}

/// Represents a recognized speech segment with speaker information
class SpeechSegment {
  /// Transcribed text content
  final String text;

  /// Start timestamp of the segment
  final DateTime startTime;

  /// End timestamp of the segment
  final DateTime endTime;

  /// Confidence score (0.0 to 1.0)
  final double confidence;

  /// Detected language for this segment
  final String language;

  /// Speaker identifier (e.g., "speaker_1", "speaker_2")
  final String speakerId;

  /// Optional speaker name if identified
  final String? speakerName;

  const SpeechSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.confidence,
    required this.language,
    required this.speakerId,
    this.speakerName,
  });

  /// Duration of the speech segment
  Duration get duration => endTime.difference(startTime);

  /// Check if this segment has valid speech content
  bool get hasValidSpeech => text.trim().isNotEmpty && confidence >= 0.5;

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'confidence': confidence,
      'language': language,
      'speakerId': speakerId,
      'speakerName': speakerName,
    };
  }

  /// Create from JSON
  factory SpeechSegment.fromJson(Map<String, dynamic> json) {
    return SpeechSegment(
      text: json['text'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      language: json['language'] as String,
      speakerId: json['speakerId'] as String,
      speakerName: json['speakerName'] as String?,
    );
  }

  @override
  String toString() =>
      'SpeechSegment(speaker: $speakerId, text: "${text.substring(0, text.length.clamp(0, 50))}...")';
}

/// Abstract interface for speech recognition implementations
abstract class SpeechRecognitionInterface {
  /// Current configuration
  SpeechRecognitionConfig get config;

  /// Whether the speech recognition system is initialized
  bool get isInitialized;

  /// Initialize the speech recognition system
  Future<bool> initialize();

  /// Process audio data and return recognized speech segments
  Future<List<SpeechSegment>> processAudio(
    Float32List audioData, {
    int sampleRate = 16000,
    DateTime? timestamp,
  });

  /// Process audio batch for better accuracy (used for 1-minute intervals)
  Future<List<SpeechSegment>> processBatch(
    List<Float32List> audioChunks, {
    int sampleRate = 16000,
    DateTime? startTime,
  });

  /// Detect the primary language from audio
  Future<String> detectLanguage(Float32List audioData);

  /// Update speaker identification based on voice characteristics
  Future<void> updateSpeakerProfile(String speakerId, Float32List voiceData);

  /// Get list of identified speakers
  List<String> get identifiedSpeakers;

  /// Clean up resources
  Future<void> dispose();
}
