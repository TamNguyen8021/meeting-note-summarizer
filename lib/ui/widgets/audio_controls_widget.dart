import 'package:flutter/material.dart';

/// Simple audio controls widget with start, pause, stop functionality
class AudioControlsWidget extends StatelessWidget {
  final bool isRecording;
  final VoidCallback? onStartRecording;
  final VoidCallback? onPauseRecording;
  final VoidCallback? onStopRecording;

  const AudioControlsWidget({
    super.key,
    required this.isRecording,
    this.onStartRecording,
    this.onPauseRecording,
    this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Start/Record button
        ElevatedButton.icon(
          onPressed: isRecording ? null : onStartRecording,
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('Start'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isRecording ? Colors.grey : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),

        // Pause button
        ElevatedButton.icon(
          onPressed: isRecording ? onPauseRecording : null,
          icon: const Icon(Icons.pause),
          label: const Text('Pause'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),

        // Stop button
        ElevatedButton.icon(
          onPressed: isRecording ? onStopRecording : null,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
