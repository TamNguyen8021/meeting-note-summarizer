import 'speech_recognition_interface.dart';

/// Configuration for text summarization
class SummarizationConfig {
  /// Target language for summaries
  final String language;

  /// Maximum length of summary sections
  final int maxSectionLength;

  /// Enable action item extraction
  final bool extractActionItems;

  /// Enable topic segmentation
  final bool enableTopicSegmentation;

  /// Temperature for text generation (0.0 to 1.0)
  final double temperature;

  const SummarizationConfig({
    this.language = 'en',
    this.maxSectionLength = 500,
    this.extractActionItems = true,
    this.enableTopicSegmentation = true,
    this.temperature = 0.3,
  });
}

/// Represents a summary of a meeting segment
class MeetingSummary {
  /// Time range this summary covers
  final DateTime startTime;
  final DateTime endTime;

  /// Main topic or theme of this segment
  final String topic;

  /// Key discussion points
  final List<String> keyPoints;

  /// Action items with assignees
  final List<ActionItem> actionItems;

  /// Participants who spoke in this segment
  final List<String> participants;

  /// Language used in this segment
  final String language;

  /// Confidence score for the summary quality
  final double confidence;

  const MeetingSummary({
    required this.startTime,
    required this.endTime,
    required this.topic,
    required this.keyPoints,
    required this.actionItems,
    required this.participants,
    required this.language,
    required this.confidence,
  });

  /// Duration covered by this summary
  Duration get duration => endTime.difference(startTime);

  /// Check if this summary has meaningful content
  bool get hasContent =>
      topic.trim().isNotEmpty || keyPoints.isNotEmpty || actionItems.isNotEmpty;

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'topic': topic,
      'keyPoints': keyPoints,
      'actionItems': actionItems.map((a) => a.toJson()).toList(),
      'participants': participants,
      'language': language,
      'confidence': confidence,
    };
  }

  /// Create from JSON
  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      topic: json['topic'] as String,
      keyPoints: List<String>.from(json['keyPoints'] as List),
      actionItems: (json['actionItems'] as List)
          .map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
          .toList(),
      participants: List<String>.from(json['participants'] as List),
      language: json['language'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  /// Create a copy with updated properties
  MeetingSummary copyWith({
    DateTime? startTime,
    DateTime? endTime,
    String? topic,
    List<String>? keyPoints,
    List<ActionItem>? actionItems,
    List<String>? participants,
    String? language,
    double? confidence,
  }) {
    return MeetingSummary(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      topic: topic ?? this.topic,
      keyPoints: keyPoints ?? this.keyPoints,
      actionItems: actionItems ?? this.actionItems,
      participants: participants ?? this.participants,
      language: language ?? this.language,
      confidence: confidence ?? this.confidence,
    );
  }

  /// Convert to map for isolate communication
  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'topic': topic,
      'keyPoints': keyPoints,
      'actionItems': actionItems.map((a) => a.toJson()).toList(),
      'participants': participants,
      'language': language,
      'confidence': confidence,
    };
  }

  /// Create from map for isolate communication
  factory MeetingSummary.fromMap(Map<String, dynamic> map) {
    return MeetingSummary(
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      topic: map['topic'] as String,
      keyPoints: List<String>.from(map['keyPoints'] as List),
      actionItems: (map['actionItems'] as List)
          .map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
          .toList(),
      participants: List<String>.from(map['participants'] as List),
      language: map['language'] as String,
      confidence: (map['confidence'] as num).toDouble(),
    );
  }
}

/// Represents an action item extracted from the meeting
class ActionItem {
  /// Description of the action to be taken
  final String description;

  /// Person assigned to this action
  final String assignee;

  /// Due date if mentioned
  final DateTime? dueDate;

  /// Priority level (high, medium, low)
  final String priority;

  /// Whether this action is completed
  final bool isCompleted;

  const ActionItem({
    required this.description,
    required this.assignee,
    this.dueDate,
    this.priority = 'medium',
    this.isCompleted = false,
  });

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'assignee': assignee,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'isCompleted': isCompleted,
    };
  }

  /// Create from JSON
  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      description: json['description'] as String,
      assignee: json['assignee'] as String,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      priority: json['priority'] as String? ?? 'medium',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

/// Abstract interface for text summarization implementations
abstract class SummarizationInterface {
  /// Current configuration
  SummarizationConfig get config;

  /// Whether the summarization system is initialized
  bool get isInitialized;

  /// Initialize the summarization system
  Future<bool> initialize();

  /// Generate summary from speech segments
  Future<MeetingSummary> generateSummary(
    List<SpeechSegment> speechSegments, {
    MeetingSummary? previousSummary,
    String? context,
  });

  /// Update an existing summary with new information
  Future<MeetingSummary> updateSummary(
    MeetingSummary existingSummary,
    List<SpeechSegment> newSegments,
  );

  /// Generate incremental summary for continuous processing
  Future<MeetingSummary> generateIncrementalSummary(
    List<MeetingSummary> previousSummaries,
    List<SpeechSegment> newSegments,
  );

  /// Extract action items from text
  Future<List<ActionItem>> extractActionItems(String text);

  /// Detect topic changes in the conversation
  Future<bool> detectTopicChange(
    List<SpeechSegment> previousSegments,
    List<SpeechSegment> newSegments,
  );

  /// Clean up resources
  Future<void> dispose();
}
