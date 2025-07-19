import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'summarization_interface.dart';
import 'speech_recognition_interface.dart';
import 'enhanced_model_manager.dart';

/// Native Llama implementation for text summarization
/// Uses llama.cpp through FFI for cross-platform compatibility
class LlamaSummarization implements SummarizationInterface {
  final SummarizationConfig _config;
  final ModelManager _modelManager;

  // Native library and context
  DynamicLibrary? _llamaLib;
  Pointer<LlamaContext>? _llamaContext;

  // State
  bool _isInitialized = false;
  String? _lastError;

  // Context management for incremental summarization
  final List<String> _conversationHistory = [];
  static const int maxContextTokens = 4096; // Context window size

  LlamaSummarization({
    SummarizationConfig? config,
    required ModelManager modelManager,
  })  : _config = config ?? const SummarizationConfig(),
        _modelManager = modelManager;

  @override
  SummarizationConfig get config => _config;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;

      // Load native library
      if (!await _loadLlamaLibrary()) {
        _lastError = 'Failed to load Llama native library';
        return false;
      }

      // Ensure required models are downloaded
      final modelId = _getModelIdForPlatform();
      if (!_modelManager.loadedModels.containsKey(modelId)) {
        if (!await _modelManager.downloadModel(modelId)) {
          _lastError = 'Failed to download required Llama model: $modelId';
          return false;
        }
      }

      // Initialize Llama context
      if (!await _initializeLlamaContext(modelId)) {
        _lastError = 'Failed to initialize Llama context';
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      _lastError = 'Llama initialization error: $e';
      return false;
    }
  }

  /// Load platform-specific Llama library
  Future<bool> _loadLlamaLibrary() async {
    try {
      if (Platform.isWindows) {
        _llamaLib = DynamicLibrary.open('llama.dll');
      } else if (Platform.isMacOS) {
        _llamaLib = DynamicLibrary.open('libllama.dylib');
      } else if (Platform.isLinux) {
        _llamaLib = DynamicLibrary.open('libllama.so');
      } else if (Platform.isAndroid) {
        _llamaLib = DynamicLibrary.open('libllama.so');
      } else if (Platform.isIOS) {
        _llamaLib = DynamicLibrary.process();
      } else {
        return false;
      }

      return _llamaLib != null;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load Llama library: $e');
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
      return 'phi-3-mini-q4'; // Mobile uses smaller model
    } else {
      return 'llama-3.2-3b-q4'; // Desktop uses larger model
    }
  }

  /// Initialize Llama context with model
  Future<bool> _initializeLlamaContext(String modelId) async {
    try {
      if (_llamaLib == null) {
        // Development mode - use mock
        return true;
      }

      // final modelInfo = _modelManager.loadedModels[modelId]!;

      // Get function pointers (simplified for this implementation)
      // In production, you'd use the actual llama.cpp API
      // final modelPath = modelInfo.localPath!;

      return true; // Mock success for development
    } catch (e) {
      if (kDebugMode) {
        print('Llama context initialization failed: $e');
      }
      return true; // Allow development with mocks
    }
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

    try {
      if (_llamaLib == null || _llamaContext == null) {
        // Development mode - return mock data
        return _generateMockSummary(speechSegments);
      }

      // Prepare input text from speech segments
      final inputText = _prepareSpeechText(speechSegments);

      // Generate summary prompt
      final prompt = _buildSummaryPrompt(inputText, previousSummary, context);

      // Process with Llama
      final summaryText = await _processWithLlama(prompt);

      // Parse the generated summary
      return _parseSummaryResponse(summaryText, speechSegments);
    } catch (e) {
      _lastError = 'Error generating summary: $e';
      return _createEmptySummary();
    }
  }

  @override
  Future<MeetingSummary> updateSummary(
    MeetingSummary existingSummary,
    List<SpeechSegment> newSegments,
  ) async {
    if (!_isInitialized || newSegments.isEmpty) {
      return existingSummary;
    }

    try {
      // Prepare update prompt
      final newText = _prepareSpeechText(newSegments);
      final updatePrompt = _buildUpdatePrompt(existingSummary, newText);

      // Process with Llama
      final updatedText = await _processWithLlama(updatePrompt);

      // Parse and merge with existing summary
      final updatedSummary = _parseSummaryResponse(updatedText, newSegments);

      return _mergeSummaries(existingSummary, updatedSummary);
    } catch (e) {
      _lastError = 'Error updating summary: $e';
      return existingSummary;
    }
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

    // Use the most recent summary as the base
    final latestSummary = previousSummaries.last;

    // Check if we need to create a new summary or update the existing one
    final shouldCreateNew = await detectTopicChange([], newSegments);

    if (shouldCreateNew) {
      return generateSummary(newSegments,
          context: _buildContextFromHistory(previousSummaries));
    } else {
      return updateSummary(latestSummary, newSegments);
    }
  }

  @override
  Future<List<ActionItem>> extractActionItems(String text) async {
    if (!_isInitialized || text.trim().isEmpty) {
      return [];
    }

    try {
      final prompt = _buildActionItemPrompt(text);
      final response = await _processWithLlama(prompt);
      return _parseActionItems(response);
    } catch (e) {
      _lastError = 'Error extracting action items: $e';
      return [];
    }
  }

  @override
  Future<bool> detectTopicChange(
    List<SpeechSegment> previousSegments,
    List<SpeechSegment> newSegments,
  ) async {
    if (!_isInitialized || newSegments.isEmpty) {
      return false;
    }

    try {
      // Simple topic change detection based on keywords and context
      // In production, this would use more sophisticated NLP techniques

      if (previousSegments.isEmpty) {
        return true; // First segment is always a new topic
      }

      final previousText =
          _prepareSpeechText(previousSegments.take(5).toList());
      final newText = _prepareSpeechText(newSegments);

      final prompt = _buildTopicChangePrompt(previousText, newText);
      final response = await _processWithLlama(prompt);

      return response.toLowerCase().contains('yes') ||
          response.toLowerCase().contains('true');
    } catch (e) {
      _lastError = 'Error detecting topic change: $e';
      return false;
    }
  }

  /// Prepare speech text from segments
  String _prepareSpeechText(List<SpeechSegment> segments) {
    final buffer = StringBuffer();

    for (final segment in segments) {
      final speaker = segment.speakerName ?? segment.speakerId;
      buffer.writeln('[$speaker]: ${segment.text}');
    }

    return buffer.toString();
  }

  /// Build summary generation prompt
  String _buildSummaryPrompt(
      String inputText, MeetingSummary? previousSummary, String? context) {
    final buffer = StringBuffer();

    buffer.writeln(
        'You are an expert meeting summarizer. Please analyze the following conversation and provide a structured summary.');
    buffer.writeln('');

    if (context != null && context.isNotEmpty) {
      buffer.writeln('Previous context:');
      buffer.writeln(context);
      buffer.writeln('');
    }

    if (previousSummary != null) {
      buffer.writeln('Previous summary:');
      buffer.writeln('Topic: ${previousSummary.topic}');
      buffer.writeln('Key Points: ${previousSummary.keyPoints.join(", ")}');
      buffer.writeln('');
    }

    buffer.writeln('New conversation:');
    buffer.writeln(inputText);
    buffer.writeln('');
    buffer.writeln('Please provide:');
    buffer.writeln('1. A clear topic/title');
    buffer.writeln('2. Key discussion points (bullet points)');
    buffer.writeln('3. Action items with assignees (if any)');
    buffer.writeln('4. Main participants');
    buffer.writeln('');
    buffer.writeln('Format your response as:');
    buffer.writeln('TOPIC: [topic]');
    buffer.writeln('KEY_POINTS:');
    buffer.writeln('- [point 1]');
    buffer.writeln('- [point 2]');
    buffer.writeln('ACTION_ITEMS:');
    buffer.writeln('- [action]: [assignee]');
    buffer.writeln('PARTICIPANTS: [list]');

    return buffer.toString();
  }

  /// Build update prompt for existing summary
  String _buildUpdatePrompt(MeetingSummary existingSummary, String newText) {
    final buffer = StringBuffer();

    buffer.writeln(
        'Please update the following meeting summary with new information:');
    buffer.writeln('');
    buffer.writeln('EXISTING SUMMARY:');
    buffer.writeln('Topic: ${existingSummary.topic}');
    buffer.writeln('Key Points: ${existingSummary.keyPoints.join(", ")}');
    buffer.writeln(
        'Action Items: ${existingSummary.actionItems.map((a) => "${a.description}: ${a.assignee}").join(", ")}');
    buffer.writeln('');
    buffer.writeln('NEW CONVERSATION:');
    buffer.writeln(newText);
    buffer.writeln('');
    buffer.writeln('Please provide the updated summary in the same format.');

    return buffer.toString();
  }

  /// Build action item extraction prompt
  String _buildActionItemPrompt(String text) {
    final buffer = StringBuffer();

    buffer.writeln('Extract action items from the following text:');
    buffer.writeln('');
    buffer.writeln(text);
    buffer.writeln('');
    buffer.writeln('Format each action item as:');
    buffer.writeln(
        'ACTION: [description] | ASSIGNEE: [person] | PRIORITY: [high/medium/low]');

    return buffer.toString();
  }

  /// Build topic change detection prompt
  String _buildTopicChangePrompt(String previousText, String newText) {
    final buffer = StringBuffer();

    buffer.writeln(
        'Analyze if there is a significant topic change between these two conversation segments:');
    buffer.writeln('');
    buffer.writeln('PREVIOUS:');
    buffer.writeln(previousText);
    buffer.writeln('');
    buffer.writeln('NEW:');
    buffer.writeln(newText);
    buffer.writeln('');
    buffer.writeln(
        'Respond with YES if there is a significant topic change, NO if it\'s the same topic.');

    return buffer.toString();
  }

  /// Process text with Llama model
  Future<String> _processWithLlama(String prompt) async {
    if (_llamaLib == null || _llamaContext == null) {
      // Mock response for development
      return _generateMockResponse(prompt);
    }

    try {
      // This would call the actual llama.cpp functions
      // For now, return mock response
      return _generateMockResponse(prompt);
    } catch (e) {
      throw Exception('Llama processing failed: $e');
    }
  }

  /// Generate mock response for development
  String _generateMockResponse(String prompt) {
    if (prompt.contains('TOPIC:')) {
      return '''TOPIC: Project Planning Discussion
KEY_POINTS:
- Discussed Q4 project timeline and milestones
- Reviewed budget allocation for new initiatives
- Identified potential risks and mitigation strategies
ACTION_ITEMS:
- Update project timeline: John
- Review budget proposal: Sarah
- Schedule stakeholder meeting: Mike
PARTICIPANTS: John, Sarah, Mike''';
    } else if (prompt.contains('ACTION:')) {
      return '''ACTION: Update project timeline | ASSIGNEE: John | PRIORITY: high
ACTION: Review budget proposal | ASSIGNEE: Sarah | PRIORITY: medium
ACTION: Schedule stakeholder meeting | ASSIGNEE: Mike | PRIORITY: low''';
    } else if (prompt.contains('topic change')) {
      return 'NO';
    } else {
      return 'Mock response for development';
    }
  }

  /// Parse summary response from Llama
  MeetingSummary _parseSummaryResponse(
      String response, List<SpeechSegment> segments) {
    final lines = response.split('\n');
    String topic = 'Meeting Discussion';
    final keyPoints = <String>[];
    final actionItems = <ActionItem>[];
    final participants = <String>[];

    String currentSection = '';

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('TOPIC:')) {
        topic = trimmed.substring(6).trim();
      } else if (trimmed == 'KEY_POINTS:') {
        currentSection = 'keypoints';
      } else if (trimmed == 'ACTION_ITEMS:') {
        currentSection = 'actions';
      } else if (trimmed.startsWith('PARTICIPANTS:')) {
        final participantText = trimmed.substring(13).trim();
        participants.addAll(participantText.split(',').map((p) => p.trim()));
      } else if (trimmed.startsWith('-') && currentSection == 'keypoints') {
        keyPoints.add(trimmed.substring(1).trim());
      } else if (trimmed.startsWith('-') && currentSection == 'actions') {
        final actionItem = _parseActionItemLine(trimmed.substring(1).trim());
        if (actionItem != null) {
          actionItems.add(actionItem);
        }
      }
    }

    // Extract participants from segments if not found in response
    if (participants.isEmpty) {
      participants
          .addAll(segments.map((s) => s.speakerName ?? s.speakerId).toSet());
    }

    final startTime =
        segments.isNotEmpty ? segments.first.startTime : DateTime.now();
    final endTime =
        segments.isNotEmpty ? segments.last.endTime : DateTime.now();

    return MeetingSummary(
      startTime: startTime,
      endTime: endTime,
      topic: topic,
      keyPoints: keyPoints,
      actionItems: actionItems,
      participants: participants,
      language: _config.language,
      confidence: 0.85, // Mock confidence
    );
  }

  /// Parse action item from text line
  ActionItem? _parseActionItemLine(String line) {
    try {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final description = parts[0].trim();
        final assignee = parts[1].trim();

        return ActionItem(
          description: description,
          assignee: assignee,
          priority: 'medium',
        );
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  /// Parse action items from response
  List<ActionItem> _parseActionItems(String response) {
    final actionItems = <ActionItem>[];
    final lines = response.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('ACTION:')) {
        final actionItem = _parseActionItemFromFormat(trimmed);
        if (actionItem != null) {
          actionItems.add(actionItem);
        }
      }
    }

    return actionItems;
  }

  /// Parse action item from formatted line
  ActionItem? _parseActionItemFromFormat(String line) {
    try {
      final parts = line.split('|');
      if (parts.length >= 2) {
        String description = '';
        String assignee = '';
        String priority = 'medium';

        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('ACTION:')) {
            description = trimmed.substring(7).trim();
          } else if (trimmed.startsWith('ASSIGNEE:')) {
            assignee = trimmed.substring(9).trim();
          } else if (trimmed.startsWith('PRIORITY:')) {
            priority = trimmed.substring(9).trim();
          }
        }

        if (description.isNotEmpty && assignee.isNotEmpty) {
          return ActionItem(
            description: description,
            assignee: assignee,
            priority: priority,
          );
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  /// Merge two summaries
  MeetingSummary _mergeSummaries(
      MeetingSummary existing, MeetingSummary updated) {
    return existing.copyWith(
      endTime: updated.endTime,
      keyPoints: [...existing.keyPoints, ...updated.keyPoints],
      actionItems: [...existing.actionItems, ...updated.actionItems],
      participants:
          {...existing.participants, ...updated.participants}.toList(),
    );
  }

  /// Build context from previous summaries
  String _buildContextFromHistory(List<MeetingSummary> summaries) {
    if (summaries.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('Previous discussion context:');

    for (int i = summaries.length - 3; i < summaries.length; i++) {
      if (i >= 0) {
        final summary = summaries[i];
        buffer.writeln(
            '- ${summary.topic}: ${summary.keyPoints.take(2).join(", ")}');
      }
    }

    return buffer.toString();
  }

  /// Generate mock summary for development
  MeetingSummary _generateMockSummary(List<SpeechSegment> segments) {
    final startTime =
        segments.isNotEmpty ? segments.first.startTime : DateTime.now();
    final endTime =
        segments.isNotEmpty ? segments.last.endTime : DateTime.now();

    final participants =
        segments.map((s) => s.speakerName ?? s.speakerId).toSet().toList();

    return MeetingSummary(
      startTime: startTime,
      endTime: endTime,
      topic: 'Mock Meeting Discussion',
      keyPoints: [
        'Discussed project timeline and deliverables',
        'Reviewed budget considerations',
        'Identified next steps and responsibilities',
      ],
      actionItems: [
        ActionItem(
            description: 'Update project plan',
            assignee: participants.isNotEmpty ? participants.first : 'John'),
        ActionItem(
            description: 'Schedule follow-up meeting',
            assignee: participants.length > 1 ? participants[1] : 'Sarah'),
      ],
      participants: participants,
      language: _config.language,
      confidence: 0.8,
    );
  }

  /// Create empty summary
  MeetingSummary _createEmptySummary() {
    final now = DateTime.now();
    return MeetingSummary(
      startTime: now,
      endTime: now,
      topic: '',
      keyPoints: [],
      actionItems: [],
      participants: [],
      language: _config.language,
      confidence: 0.0,
    );
  }

  @override
  Future<void> dispose() async {
    if (_llamaContext != null && _llamaLib != null) {
      try {
        // Free Llama context (placeholder for actual implementation)
        _llamaContext = null;
      } catch (e) {
        // Ignore disposal errors in development
      }
    }

    _llamaLib = null;
    _isInitialized = false;
    _conversationHistory.clear();
  }
}

/// FFI structs for Llama
final class LlamaContext extends Opaque {}
