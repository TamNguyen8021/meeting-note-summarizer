import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_note_summarizer/services/meeting_service.dart';
import 'package:meeting_note_summarizer/core/enums/recording_state.dart';

void main() {
  group('Meeting Service Tests', () {
    late MeetingService meetingService;

    setUp(() {
      meetingService = MeetingService();
    });

    tearDown(() {
      meetingService.dispose();
    });

    test('should initialize successfully', () async {
      final success = await meetingService.initialize();
      expect(success, isTrue);
      expect(meetingService.isAudioInitialized, isTrue);
      expect(meetingService.isAiInitialized, isTrue);
    });

    test('should start meeting successfully', () async {
      await meetingService.initialize();
      
      final started = await meetingService.startMeeting(title: 'Test Meeting');
      expect(started, isTrue);
      expect(meetingService.recordingState, RecordingState.recording);
      expect(meetingService.currentSession, isNotNull);
      expect(meetingService.currentSession!.title, 'Test Meeting');
    });

    test('should pause and resume meeting', () async {
      await meetingService.initialize();
      await meetingService.startMeeting();
      
      final paused = await meetingService.pauseMeeting();
      expect(paused, isTrue);
      expect(meetingService.recordingState, RecordingState.paused);
      
      final resumed = await meetingService.resumeMeeting();
      expect(resumed, isTrue);
      expect(meetingService.recordingState, RecordingState.recording);
    });

    test('should stop meeting successfully', () async {
      await meetingService.initialize();
      await meetingService.startMeeting();
      
      final stopped = await meetingService.stopMeeting();
      expect(stopped, isTrue);
      expect(meetingService.recordingState, RecordingState.stopped);
      expect(meetingService.currentSession?.endTime, isNotNull);
    });

    test('should handle available audio sources', () async {
      await meetingService.initialize();
      
      expect(meetingService.availableAudioSources, isNotEmpty);
      expect(meetingService.supportsSystemAudio, isTrue);
    });
  });
}
