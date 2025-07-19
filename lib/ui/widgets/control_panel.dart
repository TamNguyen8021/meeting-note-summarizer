import 'package:flutter/material.dart';
import '../../core/enums/recording_state.dart';

/// Control panel widget for managing recording state and displaying status
/// Provides recording controls, audio visualization, and status information
class ControlPanel extends StatelessWidget {
  final RecordingState recordingState;
  final double audioLevel;
  final Duration elapsedTime;
  final String currentLanguage;
  final Function(RecordingState) onRecordingStateChanged;
  final bool isCompact;

  const ControlPanel({
    super.key,
    required this.recordingState,
    required this.audioLevel,
    required this.elapsedTime,
    required this.currentLanguage,
    required this.onRecordingStateChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recording controls
          _buildRecordingControls(context),

          if (!isCompact) ...[
            const SizedBox(height: 24),
            // Audio visualizer
            _buildAudioVisualizer(context),

            const SizedBox(height: 24),
            // Status information
            _buildStatusInfo(context),
          ] else ...[
            const SizedBox(height: 16),
            // Compact status for mobile
            _buildCompactStatus(context),
          ],
        ],
      ),
    );
  }

  /// Build the main recording control buttons
  Widget _buildRecordingControls(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isCompact ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.center,
      children: [
        // Start/Resume button
        _buildControlButton(
          context: context,
          icon: recordingState == RecordingState.paused
              ? Icons.play_arrow
              : Icons.fiber_manual_record,
          label: recordingState == RecordingState.paused ? 'Resume' : 'Start',
          color: Theme.of(context).colorScheme.primary,
          onPressed: recordingState == RecordingState.recording
              ? null
              : () => onRecordingStateChanged(RecordingState.recording),
        ),

        if (!isCompact) const SizedBox(width: 16),

        // Pause button
        _buildControlButton(
          context: context,
          icon: Icons.pause,
          label: 'Pause',
          color: Colors.orange,
          onPressed: recordingState == RecordingState.recording
              ? () => onRecordingStateChanged(RecordingState.paused)
              : null,
        ),

        if (!isCompact) const SizedBox(width: 16),

        // Stop button
        _buildControlButton(
          context: context,
          icon: Icons.stop,
          label: 'Stop',
          color: Colors.red,
          onPressed: recordingState != RecordingState.stopped
              ? () => onRecordingStateChanged(RecordingState.stopped)
              : null,
        ),
      ],
    );
  }

  /// Build individual control button
  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCompact ? 48 : 64,
          height: isCompact ? 48 : 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEnabled ? color : Colors.grey.shade300,
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: Colors.white,
              size: isCompact ? 24 : 32,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: isEnabled
                ? Theme.of(context).textTheme.bodyMedium?.color
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  /// Build audio level visualizer
  Widget _buildAudioVisualizer(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Audio level bar
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade300,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: audioLevel,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        Colors.green,
                        audioLevel > 0.7 ? Colors.orange : Colors.green,
                        audioLevel > 0.9 ? Colors.red : Colors.green,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              '${(audioLevel * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Build detailed status information
  Widget _buildStatusInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              context: context,
              label: 'Status',
              value: _getStatusText(),
              valueColor: _getStatusColor(),
            ),
            _buildStatusRow(
              context: context,
              label: 'Timer',
              value: _formatDuration(elapsedTime),
            ),
            _buildStatusRow(
              context: context,
              label: 'Language',
              value: currentLanguage,
            ),
            _buildStatusRow(
              context: context,
              label: 'Source',
              value: 'System Audio', // TODO: Make this dynamic
            ),
          ],
        ),
      ),
    );
  }

  /// Build compact status for mobile layout
  Widget _buildCompactStatus(BuildContext context) {
    return Row(
      children: [
        // Status indicator
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getStatusText(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Spacer(),
        Text(
          _formatDuration(elapsedTime),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Build a status information row
  Widget _buildStatusRow({
    required BuildContext context,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }

  /// Get status text based on recording state
  String _getStatusText() {
    switch (recordingState) {
      case RecordingState.recording:
        return 'Recording';
      case RecordingState.paused:
        return 'Paused';
      case RecordingState.stopped:
        return 'Stopped';
    }
  }

  /// Get status color based on recording state
  Color _getStatusColor() {
    switch (recordingState) {
      case RecordingState.recording:
        return Colors.green;
      case RecordingState.paused:
        return Colors.orange;
      case RecordingState.stopped:
        return Colors.red;
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
