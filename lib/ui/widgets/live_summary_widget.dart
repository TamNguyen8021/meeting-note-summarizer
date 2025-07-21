import 'package:flutter/material.dart';
import '../../core/ai/summarization_interface.dart';
import '../../core/ai/speech_recognition_interface.dart';

/// Widget for displaying live meeting summaries
class LiveSummaryWidget extends StatelessWidget {
  final List<MeetingSummary> summaries;
  final List<SpeechSegment> speechSegments;
  final Function(String)? onSummarySegmentTap;

  const LiveSummaryWidget({
    super.key,
    required this.summaries,
    required this.speechSegments,
    this.onSummarySegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.summarize_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No summaries yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start recording to see live summaries',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return _buildSummaryCard(context, summary, index);
      },
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, MeetingSummary summary, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          summary.topic,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatTime(summary.startTime)} - ${_formatTime(summary.endTime)} • ${summary.participants.length} speakers',
          style: const TextStyle(fontSize: 12),
        ),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key Points
                if (summary.keyPoints.isNotEmpty) ...[
                  const Text(
                    'Key Points:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...summary.keyPoints.map((point) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(point)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],

                // Action Items
                if (summary.actionItems.isNotEmpty) ...[
                  const Text(
                    'Action Items:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...summary.actionItems.map((action) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.assignment, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(action.description),
                                  Text(
                                    'Assignee: ${action.assignee}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],

                // Participants
                if (summary.participants.isNotEmpty) ...[
                  const Text(
                    'Participants:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: summary.participants
                        .map((participant) => Chip(
                              label: Text(participant),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
