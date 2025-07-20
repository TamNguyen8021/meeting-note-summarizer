import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/meeting_session.dart';
import '../audio/audio_processing_pipeline.dart';

/// Database service for persistent storage of meeting summaries and comments
/// Handles SQLite database operations with proper schema management
class DatabaseService {
  static const String _databaseName = 'meeting_summarizer.db';
  static const int _databaseVersion = 1;

  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  /// Initialize the database with proper schema
  Future<Database> _initializeDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final databasePath = path.join(documentsDirectory.path, _databaseName);

      return await openDatabase(
        databasePath,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
        onConfigure: _configureDatabase,
      );
    } catch (e) {
      debugPrint('Database initialization failed: $e');
      rethrow;
    }
  }

  /// Configure database settings
  Future<void> _configureDatabase(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
    // Enable WAL mode for better performance
    await db.execute('PRAGMA journal_mode = WAL');
    // Set synchronous mode for better performance while maintaining safety
    await db.execute('PRAGMA synchronous = NORMAL');
  }

  /// Create database schema
  Future<void> _createDatabase(Database db, int version) async {
    await db.transaction((txn) async {
      // Meeting sessions table
      await txn.execute('''
        CREATE TABLE meeting_sessions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          start_time INTEGER NOT NULL,
          end_time INTEGER,
          primary_language TEXT DEFAULT 'EN',
          has_code_switching INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');

      // Summary segments table
      await txn.execute('''
        CREATE TABLE summary_segments (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          start_time_ms INTEGER NOT NULL,
          end_time_ms INTEGER NOT NULL,
          topic TEXT NOT NULL,
          key_points TEXT, -- JSON array
          action_items TEXT, -- JSON array
          speakers TEXT, -- JSON array
          languages TEXT, -- JSON array
          created_at INTEGER NOT NULL,
          FOREIGN KEY (session_id) REFERENCES meeting_sessions (id) ON DELETE CASCADE
        )
      ''');

      // Comments table
      await txn.execute('''
        CREATE TABLE comments (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          segment_id TEXT, -- NULL for session-level comments
          content TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          is_global INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (session_id) REFERENCES meeting_sessions (id) ON DELETE CASCADE,
          FOREIGN KEY (segment_id) REFERENCES summary_segments (id) ON DELETE CASCADE
        )
      ''');

      // Audio segments table (for processed audio metadata)
      await txn.execute('''
        CREATE TABLE audio_segments (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          duration_ms INTEGER NOT NULL,
          sample_rate INTEGER NOT NULL,
          channels INTEGER NOT NULL,
          quality_score REAL DEFAULT 0.0,
          speech_regions TEXT, -- JSON array
          analysis_data TEXT, -- JSON object
          created_at INTEGER NOT NULL,
          FOREIGN KEY (session_id) REFERENCES meeting_sessions (id) ON DELETE CASCADE
        )
      ''');

      // Settings table for app configuration
      await txn.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create indexes for better query performance
      await txn.execute(
          'CREATE INDEX idx_sessions_start_time ON meeting_sessions (start_time)');
      await txn.execute(
          'CREATE INDEX idx_segments_session_id ON summary_segments (session_id)');
      await txn.execute(
          'CREATE INDEX idx_segments_start_time ON summary_segments (start_time_ms)');
      await txn.execute(
          'CREATE INDEX idx_comments_session_id ON comments (session_id)');
      await txn.execute(
          'CREATE INDEX idx_comments_segment_id ON comments (segment_id)');
      await txn.execute(
          'CREATE INDEX idx_audio_segments_session_id ON audio_segments (session_id)');

      debugPrint('Database schema created successfully');
    });
  }

  /// Upgrade database schema for future versions
  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
  }

  // Meeting Session Operations

  /// Save a meeting session to the database
  Future<String> saveMeetingSession(MeetingSession session) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Insert or update meeting session
        await txn.insert(
          'meeting_sessions',
          _sessionToMap(session),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Delete existing segments and comments for this session
        await txn.delete('summary_segments',
            where: 'session_id = ?', whereArgs: [session.id]);
        await txn.delete('comments',
            where: 'session_id = ?', whereArgs: [session.id]);

        // Save summary segments
        for (final segment in session.segments) {
          await txn.insert(
            'summary_segments',
            _segmentToMap(segment, session.id),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Save comments
        for (final comment in session.comments) {
          await txn.insert(
            'comments',
            _commentToMap(comment, session.id),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      debugPrint('Meeting session saved: ${session.id}');
      return session.id;
    } catch (e) {
      debugPrint('Failed to save meeting session: $e');
      rethrow;
    }
  }

  /// Load a meeting session by ID
  Future<MeetingSession?> loadMeetingSession(String sessionId) async {
    final db = await database;

    try {
      // Load session data
      final sessionMaps = await db.query(
        'meeting_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      if (sessionMaps.isEmpty) return null;

      final sessionMap = sessionMaps.first;

      // Load related data
      final segments = await _loadSegmentsForSession(db, sessionId);
      final comments = await _loadCommentsForSession(db, sessionId);

      return _mapToSession(sessionMap, segments, comments);
    } catch (e) {
      debugPrint('Failed to load meeting session: $e');
      return null;
    }
  }

  /// Get all meeting sessions with optional filtering
  Future<List<MeetingSession>> getAllMeetingSessions({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (startDate != null) {
        whereClause += 'start_time >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'start_time <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }

      final sessionMaps = await db.query(
        'meeting_sessions',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'start_time DESC',
        limit: limit,
        offset: offset,
      );

      final sessions = <MeetingSession>[];

      for (final sessionMap in sessionMaps) {
        final sessionId = sessionMap['id'] as String;
        final segments = await _loadSegmentsForSession(db, sessionId);
        final comments = await _loadCommentsForSession(db, sessionId);

        sessions.add(_mapToSession(sessionMap, segments, comments));
      }

      return sessions;
    } catch (e) {
      debugPrint('Failed to load meeting sessions: $e');
      return [];
    }
  }

  /// Delete a meeting session and all related data
  Future<bool> deleteMeetingSession(String sessionId) async {
    final db = await database;

    try {
      final deletedRows = await db.delete(
        'meeting_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      debugPrint('Meeting session deleted: $sessionId');
      return deletedRows > 0;
    } catch (e) {
      debugPrint('Failed to delete meeting session: $e');
      return false;
    }
  }

  // Comment Operations

  /// Add a comment to a session or segment
  Future<String> addComment(Comment comment, String sessionId) async {
    final db = await database;

    try {
      await db.insert(
        'comments',
        _commentToMap(comment, sessionId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Comment added: ${comment.id}');
      return comment.id;
    } catch (e) {
      debugPrint('Failed to add comment: $e');
      rethrow;
    }
  }

  /// Update an existing comment
  Future<bool> updateComment(Comment comment, String sessionId) async {
    final db = await database;

    try {
      final updatedRows = await db.update(
        'comments',
        _commentToMap(comment, sessionId),
        where: 'id = ?',
        whereArgs: [comment.id],
      );

      debugPrint('Comment updated: ${comment.id}');
      return updatedRows > 0;
    } catch (e) {
      debugPrint('Failed to update comment: $e');
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    final db = await database;

    try {
      final deletedRows = await db.delete(
        'comments',
        where: 'id = ?',
        whereArgs: [commentId],
      );

      debugPrint('Comment deleted: $commentId');
      return deletedRows > 0;
    } catch (e) {
      debugPrint('Failed to delete comment: $e');
      return false;
    }
  }

  // Audio Segment Operations

  /// Save audio segment metadata
  Future<void> saveAudioSegment(
      AudioSegment audioSegment, String sessionId) async {
    final db = await database;

    try {
      await db.insert(
        'audio_segments',
        _audioSegmentToMap(audioSegment, sessionId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Audio segment metadata saved: ${audioSegment.id}');
    } catch (e) {
      debugPrint('Failed to save audio segment: $e');
      rethrow;
    }
  }

  // Settings Operations

  /// Get a setting value
  Future<String?> getSetting(String key) async {
    final db = await database;

    try {
      final result = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
      );

      return result.isNotEmpty ? result.first['value'] as String : null;
    } catch (e) {
      debugPrint('Failed to get setting: $e');
      return null;
    }
  }

  /// Set a setting value
  Future<void> setSetting(String key, String value) async {
    final db = await database;

    try {
      await db.insert(
        'settings',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Setting updated: $key = $value');
    } catch (e) {
      debugPrint('Failed to set setting: $e');
      rethrow;
    }
  }

  // Database Maintenance

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;

    try {
      final sessionCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM meeting_sessions'),
          ) ??
          0;

      final segmentCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM summary_segments'),
          ) ??
          0;

      final commentCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM comments'),
          ) ??
          0;

      final dbSize = await _getDatabaseSize();

      return {
        'sessionCount': sessionCount,
        'segmentCount': segmentCount,
        'commentCount': commentCount,
        'databaseSizeMB': dbSize,
      };
    } catch (e) {
      debugPrint('Failed to get database stats: $e');
      return {};
    }
  }

  /// Clean up old data beyond retention policy
  Future<void> cleanupOldData({int retentionDays = 90}) async {
    final db = await database;

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;

      await db.delete(
        'meeting_sessions',
        where: 'start_time < ?',
        whereArgs: [cutoffTimestamp],
      );

      debugPrint(
          'Cleanup completed: removed sessions older than $retentionDays days');
    } catch (e) {
      debugPrint('Failed to cleanup old data: $e');
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Private Helper Methods

  Future<double> _getDatabaseSize() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final databasePath = path.join(documentsDirectory.path, _databaseName);
      final file = File(databasePath);

      if (await file.exists()) {
        final sizeBytes = await file.length();
        return sizeBytes / (1024 * 1024); // Convert to MB
      }
    } catch (e) {
      debugPrint('Failed to get database size: $e');
    }
    return 0.0;
  }

  Future<List<SummarySegment>> _loadSegmentsForSession(
      Database db, String sessionId) async {
    final segmentMaps = await db.query(
      'summary_segments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'start_time_ms ASC',
    );

    return segmentMaps.map((map) => _mapToSegment(map)).toList();
  }

  Future<List<Comment>> _loadCommentsForSession(
      Database db, String sessionId) async {
    final commentMaps = await db.query(
      'comments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return commentMaps.map((map) => _mapToComment(map)).toList();
  }

  // Conversion Methods

  Map<String, dynamic> _sessionToMap(MeetingSession session) {
    return {
      'id': session.id,
      'title': session.title,
      'start_time': session.startTime.millisecondsSinceEpoch,
      'end_time': session.endTime?.millisecondsSinceEpoch,
      'primary_language': session.primaryLanguage,
      'has_code_switching': session.hasCodeSwitching ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _segmentToMap(SummarySegment segment, String sessionId) {
    return {
      'id': segment.id,
      'session_id': sessionId,
      'start_time_ms': segment.startTime.inMilliseconds,
      'end_time_ms': segment.endTime.inMilliseconds,
      'topic': segment.topic,
      'key_points': jsonEncode(segment.keyPoints),
      'action_items':
          jsonEncode(segment.actionItems.map((item) => item.toJson()).toList()),
      'speakers': jsonEncode(
          segment.speakers.map((speaker) => speaker.toJson()).toList()),
      'languages': jsonEncode(segment.languages),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _commentToMap(Comment comment, String sessionId) {
    return {
      'id': comment.id,
      'session_id': sessionId,
      'segment_id': comment.segmentId,
      'content': comment.content,
      'timestamp': comment.timestamp.millisecondsSinceEpoch,
      'is_global': comment.isGlobal ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _audioSegmentToMap(
      AudioSegment audioSegment, String sessionId) {
    return {
      'id': audioSegment.id,
      'session_id': sessionId,
      'start_time': audioSegment.startTime.millisecondsSinceEpoch,
      'end_time': audioSegment.endTime.millisecondsSinceEpoch,
      'duration_ms': audioSegment.duration.inMilliseconds,
      'sample_rate': audioSegment.sampleRate,
      'channels': audioSegment.channels,
      'quality_score': audioSegment.qualityScore,
      'speech_regions': jsonEncode(audioSegment.speechRegions
          .map((region) => {
                'startTime': region.startTime.inMilliseconds,
                'endTime': region.endTime.inMilliseconds,
                'confidence': region.confidence,
                'averageVolume': region.averageVolume,
              })
          .toList()),
      'analysis_data': jsonEncode({
        'averageVolume': audioSegment.audioAnalysis.averageVolume,
        'peakVolume': audioSegment.audioAnalysis.peakVolume,
        'noiseLevel': audioSegment.audioAnalysis.noiseLevel,
        'fundamentalFrequency': audioSegment.audioAnalysis.fundamentalFrequency,
        'spectralFeatures': audioSegment.audioAnalysis.spectralFeatures,
        'hasSpeech': audioSegment.audioAnalysis.hasSpeech,
        'overallQuality': audioSegment.audioAnalysis.overallQuality,
      }),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  MeetingSession _mapToSession(
    Map<String, dynamic> sessionMap,
    List<SummarySegment> segments,
    List<Comment> comments,
  ) {
    return MeetingSession(
      id: sessionMap['id'] as String,
      title: sessionMap['title'] as String,
      startTime:
          DateTime.fromMillisecondsSinceEpoch(sessionMap['start_time'] as int),
      endTime: sessionMap['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(sessionMap['end_time'] as int)
          : null,
      segments: segments,
      comments: comments,
      primaryLanguage: sessionMap['primary_language'] as String? ?? 'EN',
      hasCodeSwitching: (sessionMap['has_code_switching'] as int? ?? 0) == 1,
    );
  }

  SummarySegment _mapToSegment(Map<String, dynamic> map) {
    final keyPointsList =
        jsonDecode(map['key_points'] as String) as List<dynamic>;
    final actionItemsList =
        jsonDecode(map['action_items'] as String) as List<dynamic>;
    final speakersList = jsonDecode(map['speakers'] as String) as List<dynamic>;
    final languagesList =
        jsonDecode(map['languages'] as String) as List<dynamic>;

    return SummarySegment(
      id: map['id'] as String,
      startTime: Duration(milliseconds: map['start_time_ms'] as int),
      endTime: Duration(milliseconds: map['end_time_ms'] as int),
      topic: map['topic'] as String,
      keyPoints: keyPointsList.cast<String>(),
      actionItems:
          actionItemsList.map((item) => ActionItem.fromJson(item)).toList(),
      speakers:
          speakersList.map((speaker) => Speaker.fromJson(speaker)).toList(),
      languages: languagesList.cast<String>(),
    );
  }

  Comment _mapToComment(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] as String,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      segmentId: map['segment_id'] as String?,
      isGlobal: (map['is_global'] as int? ?? 0) == 1,
    );
  }
}
