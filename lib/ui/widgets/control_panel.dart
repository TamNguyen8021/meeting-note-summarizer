import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/meeting_service.dart';
import '../../core/enums/recording_state.dart';
import 'audio_visualizer.dart';
import 'ai_status_widget.dart';

class ControlPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Recording Status Header
              Row(
                children: [
                  Icon(
                    _getStatusIcon(meetingService.recordingState),
                    color: _getStatusColor(meetingService.recordingState),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    _getStatusText(meetingService.recordingState),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Spacer(),
                  Text(
                    _formatDuration(meetingService.currentDuration),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Audio Visualizer
              Container(
                height: 60,
                child: AudioVisualizer(
                  isRecording:
                      meetingService.recordingState == RecordingState.recording,
                  height: 60,
                ),
              ),

              SizedBox(height: 20),

              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Start/Resume button
                  if (meetingService.recordingState == RecordingState.stopped ||
                      meetingService.recordingState == RecordingState.paused)
                    _buildControlButton(
                      context,
                      icon: meetingService.recordingState ==
                              RecordingState.stopped
                          ? Icons.play_arrow
                          : Icons.play_arrow,
                      label: meetingService.recordingState ==
                              RecordingState.stopped
                          ? 'Start'
                          : 'Resume',
                      color: Colors.green,
                      onPressed: () async {
                        try {
                          if (meetingService.recordingState ==
                              RecordingState.stopped) {
                            await meetingService.startMeeting();
                          } else {
                            await meetingService.resumeMeeting();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                    ),

                  // Pause button
                  if (meetingService.recordingState == RecordingState.recording)
                    _buildControlButton(
                      context,
                      icon: Icons.pause,
                      label: 'Pause',
                      color: Colors.orange,
                      onPressed: () async {
                        try {
                          await meetingService.pauseMeeting();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                    ),

                  // Stop button
                  if (meetingService.recordingState != RecordingState.stopped)
                    _buildControlButton(
                      context,
                      icon: Icons.stop,
                      label: 'Stop',
                      color: Colors.red,
                      onPressed: () async {
                        try {
                          await meetingService.stopMeeting();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                ],
              ),

              SizedBox(height: 20),

              // AI Status Widget
              AiStatusWidget(),

              // Recording Info
              if (meetingService.recordingState != RecordingState.stopped) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mic,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Segments: ${meetingService.liveSegments.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Spacer(),
                      Icon(
                        Icons.memory,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Processing...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  IconData _getStatusIcon(RecordingState state) {
    switch (state) {
      case RecordingState.stopped:
        return Icons.radio_button_unchecked;
      case RecordingState.recording:
        return Icons.fiber_manual_record;
      case RecordingState.paused:
        return Icons.pause_circle;
    }
  }

  Color _getStatusColor(RecordingState state) {
    switch (state) {
      case RecordingState.stopped:
        return Colors.grey;
      case RecordingState.recording:
        return Colors.red;
      case RecordingState.paused:
        return Colors.orange;
    }
  }

  String _getStatusText(RecordingState state) {
    switch (state) {
      case RecordingState.stopped:
        return 'Ready to Record';
      case RecordingState.recording:
        return 'Recording';
      case RecordingState.paused:
        return 'Paused';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}
