import 'dart:math';

import '../core/ai/speech_recognition_interface.dart';
import '../core/ai/summarization_interface.dart';

/// Mock implementation of text summarization for development and testing
/// This will be replaced with actual LLM integration later
class MockSummarization implements SummarizationInterface {
  final SummarizationConfig _config;
  bool _isInitialized = false;
  final Random _random = Random();

  MockSummarization({SummarizationConfig? config})
      : _config = config ?? const SummarizationConfig();

  @override
  SummarizationConfig get config => _config;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<bool> initialize() async {
    // Simulate initialization delay
    await Future.delayed(const Duration(milliseconds: 300));
    _isInitialized = true;
    return true;
  }

  @override
  Future<MeetingSummary> generateSummary(
    List<SpeechSegment> speechSegments, {
    MeetingSummary? previousSummary,
    String? context,
  }) async {
    if (!_isInitialized || speechSegments.isEmpty) {
      return _createEmptySummary();
    }

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 500));

    final startTime = speechSegments.first.startTime;
    final endTime = speechSegments.last.endTime;

    // Extract participants from speech segments
    final participants = speechSegments
        .map((s) => s.speakerName ?? s.speakerId)
        .toSet()
        .toList();

    // Generate mock topic
    final topics = [
      'Quarterly Review',
      'Project Planning',
      'Budget Discussion',
      'Team Updates',
      'Client Requirements',
      'Technical Architecture',
      'Market Analysis',
      'Strategy Session',
    ];
    final topic = topics[_random.nextInt(topics.length)];

    // Generate mock key points
    final keyPoints = _generateKeyPoints(speechSegments);

    // Generate mock action items
    final actionItems = _generateActionItems(participants);

    // Calculate confidence based on speech segment confidence
    final avgConfidence = speechSegments.isNotEmpty
        ? speechSegments.map((s) => s.confidence).reduce((a, b) => a + b) /
            speechSegments.length
        : 0.7;

    return MeetingSummary(
      startTime: startTime,
      endTime: endTime,
      topic: topic,
      keyPoints: keyPoints,
      actionItems: actionItems,
      participants: participants,
      language: _config.language,
      confidence: avgConfidence,
    );
  }

  @override
  Future<MeetingSummary> updateSummary(
    MeetingSummary existingSummary,
    List<SpeechSegment> newSegments,
  ) async {
    if (!_isInitialized || newSegments.isEmpty) {
      return existingSummary;
    }

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Extend the time range
    final newEndTime = newSegments.last.endTime;

    // Add new participants
    final newParticipants =
        newSegments.map((s) => s.speakerName ?? s.speakerId).toSet().toList();

    final allParticipants = {
      ...existingSummary.participants,
      ...newParticipants,
    }.toList();

    // Add new key points
    final newKeyPoints = _generateKeyPoints(newSegments, isUpdate: true);
    final allKeyPoints = [
      ...existingSummary.keyPoints,
      ...newKeyPoints,
    ];

    // Add new action items
    final newActionItems =
        _generateActionItems(newParticipants, isUpdate: true);
    final allActionItems = [
      ...existingSummary.actionItems,
      ...newActionItems,
    ];

    return existingSummary.copyWith(
      endTime: newEndTime,
      keyPoints: allKeyPoints,
      actionItems: allActionItems,
      participants: allParticipants,
    );
  }

  @override
  Future<MeetingSummary> generateIncrementalSummary(
    List<MeetingSummary> previousSummaries,
    List<SpeechSegment> newSegments,
  ) async {
    if (!_isInitialized || newSegments.isEmpty) {
      return _createEmptySummary();
    }

    if (previousSummaries.isEmpty) {
      return generateSummary(newSegments);
    }

    // Update the most recent summary
    final lastSummary = previousSummaries.last;
    return updateSummary(lastSummary, newSegments);
  }

  @override
  Future<List<ActionItem>> extractActionItems(String text) async {
    if (!_isInitialized) return [];

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Simple mock action item extraction
    final actionKeywords = [
      'action',
      'todo',
      'follow up',
      'schedule',
      'review',
      'complete',
      'deliver',
      'submit',
    ];

    final hasActionKeyword = actionKeywords.any(
      (keyword) => text.toLowerCase().contains(keyword),
    );

    if (!hasActionKeyword) return [];

    // Generate mock action items
    return _generateActionItems(['John', 'Sarah'], isUpdate: false);
  }

  @override
  Future<bool> detectTopicChange(
    List<SpeechSegment> previousSegments,
    List<SpeechSegment> newSegments,
  ) async {
    if (!_isInitialized) return false;

    // Simple mock topic change detection
    // In a real implementation, this would use semantic analysis
    await Future.delayed(const Duration(milliseconds: 50));

    // Randomly detect topic changes for testing
    return _random.nextDouble() < 0.2; // 20% chance of topic change
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  /// Generate mock key points from speech segments
  List<String> _generateKeyPoints(
    List<SpeechSegment> segments, {
    bool isUpdate = false,
  }) {
    final keyPointTemplates = [
      'Discussed current project status and timeline',
      'Reviewed budget allocation for the quarter',
      'Addressed client concerns and requirements',
      'Planned next steps for development',
      'Evaluated team performance metrics',
      'Analyzed market trends and opportunities',
      'Coordinated cross-team collaboration',
      'Identified potential risks and mitigation strategies',
    ];

    final updateTemplates = [
      'Continued discussion on implementation details',
      'Further clarified requirements and scope',
      'Addressed additional questions and concerns',
      'Refined timeline and deliverables',
    ];

    final templates = isUpdate ? updateTemplates : keyPointTemplates;
    final numPoints = _random.nextInt(3) + 1; // 1-3 key points

    return List.generate(
      numPoints,
      (index) => templates[_random.nextInt(templates.length)],
    );
  }

  /// Generate mock action items
  List<ActionItem> _generateActionItems(
    List<String> participants, {
    bool isUpdate = false,
  }) {
    if (participants.isEmpty) return [];

    final actionTemplates = [
      'Schedule follow-up meeting',
      'Review and approve budget proposal',
      'Submit project deliverables',
      'Coordinate with external stakeholders',
      'Prepare presentation for next meeting',
      'Update project documentation',
      'Conduct user research and analysis',
      'Implement technical requirements',
    ];

    final updateTemplates = [
      'Follow up on previous action items',
      'Provide status update on assigned tasks',
      'Address outstanding issues',
      'Coordinate next phase activities',
    ];

    final templates = isUpdate ? updateTemplates : actionTemplates;
    final numActions = _random.nextInt(2) + 1; // 1-2 action items

    return List.generate(numActions, (index) {
      final assignee = participants[_random.nextInt(participants.length)];
      final description = templates[_random.nextInt(templates.length)];

      return ActionItem(
        description: description,
        assignee: assignee,
        dueDate: DateTime.now().add(Duration(days: _random.nextInt(14) + 1)),
        priority: ['high', 'medium', 'low'][_random.nextInt(3)],
      );
    });
  }

  /// Create an empty summary for fallback cases
  MeetingSummary _createEmptySummary() {
    final now = DateTime.now();
    return MeetingSummary(
      startTime: now,
      endTime: now,
      topic: 'No Content',
      keyPoints: [],
      actionItems: [],
      participants: [],
      language: _config.language,
      confidence: 0.0,
    );
  }
}
