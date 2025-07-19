/// Enumeration of possible recording states for the meeting summarizer
enum RecordingState {
  /// Recording is currently active and processing audio
  recording,

  /// Recording is temporarily paused but can be resumed
  paused,

  /// Recording is stopped and session can be saved/exported
  stopped,
}
