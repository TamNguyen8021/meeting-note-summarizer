/// Represents a single meeting session with its metadata and content
class MeetingSession {
  /// Unique identifier for the session
  final String id;

  /// User-defined title for the meeting
  final String title;

  /// When the meeting session was started
  final DateTime startTime;

  /// When the meeting session ended (null if ongoing)
  final DateTime? endTime;

  /// List of summary segments generated during the meeting
  final List<SummarySegment> segments;

  /// List of user comments associated with this session
  final List<Comment> comments;

  /// Primary language detected/used in the meeting
  final String primaryLanguage;

  /// Whether code-switching was detected
  final bool hasCodeSwitching;

  const MeetingSession({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.segments = const [],
    this.comments = const [],
    this.primaryLanguage = 'EN',
    this.hasCodeSwitching = false,
  });

  /// Create a copy of this session with updated properties
  MeetingSession copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    List<SummarySegment>? segments,
    List<Comment>? comments,
    String? primaryLanguage,
    bool? hasCodeSwitching,
  }) {
    return MeetingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      segments: segments ?? this.segments,
      comments: comments ?? this.comments,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      hasCodeSwitching: hasCodeSwitching ?? this.hasCodeSwitching,
    );
  }

  /// Get the total duration of the meeting
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Check if the meeting is currently active
  bool get isActive => endTime == null;

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'segments': segments.map((s) => s.toJson()).toList(),
      'comments': comments.map((c) => c.toJson()).toList(),
      'primaryLanguage': primaryLanguage,
      'hasCodeSwitching': hasCodeSwitching,
    };
  }

  /// Create from JSON for persistence
  factory MeetingSession.fromJson(Map<String, dynamic> json) {
    return MeetingSession(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      segments: (json['segments'] as List<dynamic>?)
              ?.map((s) => SummarySegment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => Comment.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      primaryLanguage: json['primaryLanguage'] as String? ?? 'EN',
      hasCodeSwitching: json['hasCodeSwitching'] as bool? ?? false,
    );
  }
}

/// Represents a time-based segment of the meeting summary
class SummarySegment {
  /// Unique identifier for the segment
  final String id;

  /// Start time relative to meeting start
  final Duration startTime;

  /// End time relative to meeting start
  final Duration endTime;

  /// Main topic or subject of this segment
  final String topic;

  /// Key discussion points in this segment
  final List<String> keyPoints;

  /// Action items identified in this segment
  final List<ActionItem> actionItems;

  /// Speakers who participated in this segment
  final List<Speaker> speakers;

  /// Language(s) used in this segment
  final List<String> languages;

  const SummarySegment({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.topic,
    this.keyPoints = const [],
    this.actionItems = const [],
    this.speakers = const [],
    this.languages = const ['EN'],
  });

  /// Create a copy of this segment with updated properties
  SummarySegment copyWith({
    String? id,
    Duration? startTime,
    Duration? endTime,
    String? topic,
    List<String>? keyPoints,
    List<ActionItem>? actionItems,
    List<Speaker>? speakers,
    List<String>? languages,
  }) {
    return SummarySegment(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      topic: topic ?? this.topic,
      keyPoints: keyPoints ?? this.keyPoints,
      actionItems: actionItems ?? this.actionItems,
      speakers: speakers ?? this.speakers,
      languages: languages ?? this.languages,
    );
  }

  /// Format time duration for display
  String get timeRange {
    final start = _formatDuration(startTime);
    final end = _formatDuration(endTime);
    return '$start - $end';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.inMilliseconds,
      'endTime': endTime.inMilliseconds,
      'topic': topic,
      'keyPoints': keyPoints,
      'actionItems': actionItems.map((a) => a.toJson()).toList(),
      'speakers': speakers.map((s) => s.toJson()).toList(),
      'languages': languages,
    };
  }

  /// Create from JSON for persistence
  factory SummarySegment.fromJson(Map<String, dynamic> json) {
    return SummarySegment(
      id: json['id'] as String,
      startTime: Duration(milliseconds: json['startTime'] as int),
      endTime: Duration(milliseconds: json['endTime'] as int),
      topic: json['topic'] as String,
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      actionItems: (json['actionItems'] as List<dynamic>?)
              ?.map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      speakers: (json['speakers'] as List<dynamic>?)
              ?.map((s) => Speaker.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['EN'],
    );
  }
}

/// Represents an action item identified in the meeting
class ActionItem {
  /// Unique identifier for the action item
  final String id;

  /// Description of the action to be taken
  final String description;

  /// Person assigned to this action item
  final String? assignee;

  /// Due date for the action item
  final DateTime? dueDate;

  /// Priority level of the action item
  final Priority priority;

  const ActionItem({
    required this.id,
    required this.description,
    this.assignee,
    this.dueDate,
    this.priority = Priority.medium,
  });

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'assignee': assignee,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority.toString(),
    };
  }

  /// Create from JSON for persistence
  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id'] as String,
      description: json['description'] as String,
      assignee: json['assignee'] as String?,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      priority: Priority.values.firstWhere(
        (p) => p.toString() == json['priority'],
        orElse: () => Priority.medium,
      ),
    );
  }
}

/// Represents a speaker in the meeting
class Speaker {
  /// Unique identifier for the speaker
  final String id;

  /// Display name for the speaker
  final String? name;

  /// Voice characteristics for identification
  final Map<String, dynamic>? voiceProfile;

  const Speaker({
    required this.id,
    this.name,
    this.voiceProfile,
  });

  /// Get display name or fallback to ID
  String get displayName => name ?? 'Speaker ${id.replaceAll('speaker_', '')}';

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'voiceProfile': voiceProfile,
    };
  }

  /// Create from JSON for persistence
  factory Speaker.fromJson(Map<String, dynamic> json) {
    return Speaker(
      id: json['id'] as String,
      name: json['name'] as String?,
      voiceProfile: json['voiceProfile'] as Map<String, dynamic>?,
    );
  }
}

/// Represents a user comment on the meeting
class Comment {
  /// Unique identifier for the comment
  final String id;

  /// Content of the comment
  final String content;

  /// When the comment was created
  final DateTime timestamp;

  /// Optional link to a specific segment
  final String? segmentId;

  /// Whether this comment applies to the entire session
  final bool isGlobal;

  const Comment({
    required this.id,
    required this.content,
    required this.timestamp,
    this.segmentId,
    this.isGlobal = false,
  });

  /// Create a copy of this comment with updated properties
  Comment copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    String? segmentId,
    bool? isGlobal,
  }) {
    return Comment(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      segmentId: segmentId ?? this.segmentId,
      isGlobal: isGlobal ?? this.isGlobal,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'segmentId': segmentId,
      'isGlobal': isGlobal,
    };
  }

  /// Create from JSON for persistence
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      segmentId: json['segmentId'] as String?,
      isGlobal: json['isGlobal'] as bool? ?? false,
    );
  }
}

/// Priority levels for action items
enum Priority {
  low,
  medium,
  high,
  urgent,
}
