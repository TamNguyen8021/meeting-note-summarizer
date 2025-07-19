/// Represents an available audio source for capture
class AudioSource {
  /// Unique identifier for the audio source
  final String id;

  /// Human-readable name of the audio source
  final String name;

  /// Type of audio source (microphone, system, virtual)
  final AudioSourceType type;

  /// Whether this source is currently available
  final bool isAvailable;

  /// Platform-specific device information
  final Map<String, dynamic>? deviceInfo;

  const AudioSource({
    required this.id,
    required this.name,
    required this.type,
    this.isAvailable = true,
    this.deviceInfo,
  });

  @override
  String toString() => 'AudioSource($name, $type, available: $isAvailable)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSource &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isAvailable': isAvailable,
      'deviceInfo': deviceInfo,
    };
  }

  /// Create from JSON
  factory AudioSource.fromJson(Map<String, dynamic> json) {
    return AudioSource(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AudioSourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AudioSourceType.microphone,
      ),
      isAvailable: json['isAvailable'] as bool? ?? true,
      deviceInfo: json['deviceInfo'] as Map<String, dynamic>?,
    );
  }
}

/// Types of audio sources available for capture
enum AudioSourceType {
  /// Built-in or external microphone
  microphone,

  /// System audio output (speakers/headphones)
  system,

  /// Virtual audio cable or software routing
  virtual,

  /// Line input or other analog input
  lineIn,

  /// Unknown or unsupported type
  unknown,
}
