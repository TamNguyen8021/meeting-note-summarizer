import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/database_service.dart';
import '../models/meeting_session.dart';
import '../audio/audio_processing_pipeline.dart';

/// Repository interface for meeting data operations
/// Provides a clean API layer over the database service
abstract class MeetingRepository {
  // Session operations
  Future<String> saveMeetingSession(MeetingSession session);
  Future<MeetingSession?> getMeetingSession(String sessionId);
  Future<List<MeetingSession>> getAllMeetingSessions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<bool> deleteMeetingSession(String sessionId);
  
  // Comment operations
  Future<String> addComment(Comment comment, String sessionId);
  Future<bool> updateComment(Comment comment, String sessionId);
  Future<bool> deleteComment(String commentId);
  
  // Audio segment operations
  Future<void> saveAudioSegment(AudioSegment audioSegment, String sessionId);
  
  // Settings operations
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  
  // Maintenance operations
  Future<Map<String, dynamic>> getDatabaseStats();
  Future<void> cleanupOldData({int retentionDays = 90});
}

/// Implementation of MeetingRepository using SQLite database
class SQLiteMeetingRepository implements MeetingRepository {
  final DatabaseService _databaseService;
  
  SQLiteMeetingRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  @override
  Future<String> saveMeetingSession(MeetingSession session) async {
    try {
      return await _databaseService.saveMeetingSession(session);
    } catch (e) {
      debugPrint('Repository: Failed to save meeting session: $e');
      rethrow;
    }
  }

  @override
  Future<MeetingSession?> getMeetingSession(String sessionId) async {
    try {
      return await _databaseService.loadMeetingSession(sessionId);
    } catch (e) {
      debugPrint('Repository: Failed to get meeting session: $e');
      return null;
    }
  }

  @override
  Future<List<MeetingSession>> getAllMeetingSessions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _databaseService.getAllMeetingSessions(
        limit: limit,
        offset: offset,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Repository: Failed to get all meeting sessions: $e');
      return [];
    }
  }

  @override
  Future<bool> deleteMeetingSession(String sessionId) async {
    try {
      return await _databaseService.deleteMeetingSession(sessionId);
    } catch (e) {
      debugPrint('Repository: Failed to delete meeting session: $e');
      return false;
    }
  }

  @override
  Future<String> addComment(Comment comment, String sessionId) async {
    try {
      return await _databaseService.addComment(comment, sessionId);
    } catch (e) {
      debugPrint('Repository: Failed to add comment: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateComment(Comment comment, String sessionId) async {
    try {
      return await _databaseService.updateComment(comment, sessionId);
    } catch (e) {
      debugPrint('Repository: Failed to update comment: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteComment(String commentId) async {
    try {
      return await _databaseService.deleteComment(commentId);
    } catch (e) {
      debugPrint('Repository: Failed to delete comment: $e');
      return false;
    }
  }

  @override
  Future<void> saveAudioSegment(AudioSegment audioSegment, String sessionId) async {
    try {
      await _databaseService.saveAudioSegment(audioSegment, sessionId);
    } catch (e) {
      debugPrint('Repository: Failed to save audio segment: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getSetting(String key) async {
    try {
      return await _databaseService.getSetting(key);
    } catch (e) {
      debugPrint('Repository: Failed to get setting: $e');
      return null;
    }
  }

  @override
  Future<void> setSetting(String key, String value) async {
    try {
      await _databaseService.setSetting(key, value);
    } catch (e) {
      debugPrint('Repository: Failed to set setting: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      return await _databaseService.getDatabaseStats();
    } catch (e) {
      debugPrint('Repository: Failed to get database stats: $e');
      return {};
    }
  }

  @override
  Future<void> cleanupOldData({int retentionDays = 90}) async {
    try {
      await _databaseService.cleanupOldData(retentionDays: retentionDays);
    } catch (e) {
      debugPrint('Repository: Failed to cleanup old data: $e');
    }
  }
}

/// In-memory implementation for testing purposes
class InMemoryMeetingRepository implements MeetingRepository {
  final Map<String, MeetingSession> _sessions = {};
  final Map<String, Comment> _comments = {};
  final Map<String, AudioSegment> _audioSegments = {};
  final Map<String, String> _settings = {};

  @override
  Future<String> saveMeetingSession(MeetingSession session) async {
    _sessions[session.id] = session;
    return session.id;
  }

  @override
  Future<MeetingSession?> getMeetingSession(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
  Future<List<MeetingSession>> getAllMeetingSessions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var sessions = _sessions.values.toList();
    
    // Filter by date range
    if (startDate != null) {
      sessions = sessions.where((s) => s.startTime.isAfter(startDate) || s.startTime.isAtSameMomentAs(startDate)).toList();
    }
    if (endDate != null) {
      sessions = sessions.where((s) => s.startTime.isBefore(endDate) || s.startTime.isAtSameMomentAs(endDate)).toList();
    }
    
    // Sort by start time (newest first)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    
    // Apply pagination
    if (offset != null) {
      sessions = sessions.skip(offset).toList();
    }
    if (limit != null) {
      sessions = sessions.take(limit).toList();
    }
    
    return sessions;
  }

  @override
  Future<bool> deleteMeetingSession(String sessionId) async {
    final removed = _sessions.remove(sessionId);
    
    // Remove related comments and audio segments
    _comments.removeWhere((key, comment) => comment.segmentId != null && 
        _sessions[sessionId]?.segments.any((s) => s.id == comment.segmentId) == true);
    _audioSegments.removeWhere((key, segment) => key.startsWith(sessionId));
    
    return removed != null;
  }

  @override
  Future<String> addComment(Comment comment, String sessionId) async {
    _comments[comment.id] = comment;
    return comment.id;
  }

  @override
  Future<bool> updateComment(Comment comment, String sessionId) async {
    if (_comments.containsKey(comment.id)) {
      _comments[comment.id] = comment;
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteComment(String commentId) async {
    return _comments.remove(commentId) != null;
  }

  @override
  Future<void> saveAudioSegment(AudioSegment audioSegment, String sessionId) async {
    _audioSegments['${sessionId}_${audioSegment.id}'] = audioSegment;
  }

  @override
  Future<String?> getSetting(String key) async {
    return _settings[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    return {
      'sessionCount': _sessions.length,
      'segmentCount': _sessions.values.fold<int>(0, (sum, session) => sum + session.segments.length),
      'commentCount': _comments.length,
      'databaseSizeMB': 0.0, // Not applicable for in-memory
    };
  }

  @override
  Future<void> cleanupOldData({int retentionDays = 90}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    
    _sessions.removeWhere((key, session) => session.startTime.isBefore(cutoffDate));
    
    // Clean up orphaned data
    final sessionIds = _sessions.keys.toSet();
    _comments.removeWhere((key, comment) => 
        comment.segmentId != null && 
        !sessionIds.any((sessionId) => 
            _sessions[sessionId]?.segments.any((s) => s.id == comment.segmentId) == true));
    
    _audioSegments.removeWhere((key, segment) => 
        !sessionIds.any((sessionId) => key.startsWith(sessionId)));
  }

  /// Clear all data (useful for testing)
  void clear() {
    _sessions.clear();
    _comments.clear();
    _audioSegments.clear();
    _settings.clear();
  }
}
