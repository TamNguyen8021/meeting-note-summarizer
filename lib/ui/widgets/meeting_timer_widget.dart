import 'package:flutter/material.dart';

/// Simple meeting timer widget that shows elapsed time
class MeetingTimerWidget extends StatefulWidget {
  final bool isActive;
  final DateTime? startTime;
  final bool compact;

  const MeetingTimerWidget({
    super.key,
    required this.isActive,
    this.startTime,
    this.compact = false,
  });

  @override
  State<MeetingTimerWidget> createState() => _MeetingTimerWidgetState();
}

class _MeetingTimerWidgetState extends State<MeetingTimerWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  String _elapsedTime = '00:00';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    if (widget.isActive) {
      _animationController.repeat();
    }

    _updateTimer();
  }

  @override
  void didUpdateWidget(MeetingTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }

    _updateTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateTimer() {
    if (widget.startTime != null) {
      final elapsed = DateTime.now().difference(widget.startTime!);
      setState(() {
        _elapsedTime = _formatDuration(elapsed);
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Update timer every animation frame when active
        if (widget.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateTimer();
          });
        }

        return widget.compact ? _buildCompactTimer() : _buildFullTimer();
      },
    );
  }

  Widget _buildCompactTimer() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isActive)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        if (widget.isActive) const SizedBox(width: 4),
        Text(
          _elapsedTime,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFullTimer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.isActive) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Text(
                  'Meeting Duration',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _elapsedTime,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
