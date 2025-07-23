import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/meeting_session.dart';
import '../../services/meeting_service.dart';

/// Widget for displaying live and completed meeting summaries
/// Shows summary segments with collapsible sections and real-time updates
class SummaryView extends StatefulWidget {
  final MeetingSession? session;
  final bool isLive;

  const SummaryView({
    super.key,
    this.session,
    this.isLive = false,
  });

  @override
  State<SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<SummaryView> {
  final ScrollController _scrollController = ScrollController();
  Set<String> _expandedSegments = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Auto-scroll to bottom when new content is added in live mode
  void _scrollToBottom() {
    if (widget.isLive && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        if (widget.session == null) {
          return _buildEmptyState(context);
        }

        final session = widget.session!;

        // Show live segments when available, otherwise use session segments
        // Keep showing live segments even when paused if they exist
        final segments = meetingService.liveSegments.isNotEmpty
            ? meetingService.liveSegments
            : session.segments;

        // Auto-scroll when new segments are added
        if (widget.isLive && segments.isNotEmpty) {
          _scrollToBottom();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with session info
              _buildHeader(context, session),

              const SizedBox(height: 16),

              // Summary content
              Expanded(
                child: segments.isEmpty
                    ? _buildNoSummaryState(context)
                    : _buildSummaryList(context, session, segments),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build empty state when no session is available
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.summarize_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Meeting Session',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording to begin generating summaries',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  /// Build state when session exists but no summaries yet
  Widget _buildNoSummaryState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLive) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating Summary...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Summaries will appear here every minute',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ] else ...[
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Summary Available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build header with session information
  Widget _buildHeader(BuildContext context, MeetingSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isLive ? Icons.radio_button_checked : Icons.article,
                  color: widget.isLive ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.isLive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Started: ${_formatDateTime(session.startTime)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Text(
                  'Duration: ${_formatDuration(session.duration)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!widget.isLive && session.endTime != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Ended: ${_formatDateTime(session.endTime!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build list of summary segments
  Widget _buildSummaryList(BuildContext context, MeetingSession session,
      List<SummarySegment> segments) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        final isExpanded = _expandedSegments.contains(segment.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ExpansionTile(
              title: Text(
                segment.topic,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${segment.timeRange} • ${segment.speakers.length} speaker(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              leading: CircleAvatar(
                backgroundColor: widget.isLive
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                child: widget.isLive
                    ? const Icon(Icons.radio_button_checked,
                        color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedSegments.add(segment.id);
                  } else {
                    _expandedSegments.remove(segment.id);
                  }
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Key Points
                      if (segment.keyPoints.isNotEmpty) ...[
                        Text(
                          'Key Points:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...segment.keyPoints.map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(point)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Action Items
                      if (segment.actionItems.isNotEmpty) ...[
                        Text(
                          'Action Items:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...segment.actionItems.map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.description,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  if (action.assignee != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Assigned to: ${action.assignee}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Speakers
                      if (segment.speakers.isNotEmpty) ...[
                        Text(
                          'Participants:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: segment.speakers
                              .map(
                                (speaker) => Chip(
                                  label: Text(speaker.displayName),
                                  avatar: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                    child: Text(
                                      speaker.displayName[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format Duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
