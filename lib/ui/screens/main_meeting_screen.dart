import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/meeting_service.dart';
import '../../core/ai/enhanced_model_manager.dart';
import '../../core/ai/summarization_interface.dart' as ai_summary;
import '../../core/enums/recording_state.dart';
import '../widgets/audio_controls_widget.dart';
import '../widgets/live_summary_widget.dart';
import '../widgets/comments_widget.dart';
import '../widgets/meeting_timer_widget.dart';
import '../widgets/language_indicator_widget.dart';
import '../widgets/model_download_progress.dart';
import '../widgets/model_manager_debug.dart';

/// Main meeting screen with real-time summarization
/// Implements the responsive design from the requirements
class MainMeetingScreen extends StatefulWidget {
  const MainMeetingScreen({super.key});

  @override
  State<MainMeetingScreen> createState() => _MainMeetingScreenState();
}

class _MainMeetingScreenState extends State<MainMeetingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  bool _isInitialized = false;
  String? _errorMessage;

  // Responsive layout breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
    _setupDownloadNotifications();
  }

  /// Setup download completion notifications
  void _setupDownloadNotifications() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modelManager = Provider.of<ModelManager>(context, listen: false);
      modelManager.addListener(_onModelManagerUpdate);
    });
  }

  /// Handle model manager updates for download notifications
  void _onModelManagerUpdate() {
    final modelManager = Provider.of<ModelManager>(context, listen: false);
    final downloadStates = modelManager.downloadStates;

    // Check for recently completed downloads
    for (final entry in downloadStates.entries) {
      if (entry.value.isCompleted && entry.value.error == null) {
        final modelInfo = modelManager.availableModels[entry.key];
        if (modelInfo != null) {
          _showDownloadCompletedNotification(modelInfo.name);
        }
      }
    }
  }

  /// Show download completion notification
  void _showDownloadCompletedNotification(String modelName) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$modelName downloaded successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Remove model manager listener
    try {
      final modelManager = Provider.of<ModelManager>(context, listen: false);
      modelManager.removeListener(_onModelManagerUpdate);
    } catch (e) {
      // Provider might not be available during dispose
    }
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize meeting service
  Future<void> _initializeServices() async {
    try {
      final meetingService =
          Provider.of<MeetingService>(context, listen: false);

      // Wait for the service to initialize if it hasn't already
      if (!meetingService.isInitialized) {
        debugPrint('Waiting for MeetingService to initialize...');
        await meetingService.initialize();
      }

      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize services: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        return Scaffold(
          appBar: _buildAppBar(meetingService),
          body: _isInitialized
              ? _buildMainContent(meetingService)
              : _buildLoadingScreen(),
          bottomNavigationBar: _errorMessage != null ? _buildErrorBar() : null,
        );
      },
    );
  }

  /// Build responsive app bar
  PreferredSizeWidget _buildAppBar(MeetingService meetingService) {
    return AppBar(
      title: const Text('Meeting Summarizer'),
      elevation: 0,
      actions: [
        // Compact download status indicator
        _buildCompactDownloadIndicator(),
        const SizedBox(width: 8),
        // Language indicator
        LanguageIndicatorWidget(
          currentLanguage: meetingService.currentLanguage,
          onLanguageChange: _handleLanguageChange,
        ),
        const SizedBox(width: 8),
        // Export button
        IconButton(
          icon: const Icon(Icons.file_download),
          onPressed: _handleExport,
          tooltip: 'Export Summary',
        ),
        // Settings
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  /// Build main content with responsive layout
  Widget _buildMainContent(MeetingService meetingService) {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final hasActiveDownloads = modelManager.downloadStates.values
            .any((state) => state.isDownloading);

        return Column(
          children: [
            // Always show download progress at the top when active
            if (hasActiveDownloads)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const ModelDownloadProgress(),
              ),
            // Main content
            Expanded(
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= tabletBreakpoint) {
                        return _buildDesktopLayout();
                      } else if (constraints.maxWidth >= mobileBreakpoint) {
                        return _buildTabletLayout();
                      } else {
                        return _buildMobileLayout();
                      }
                    },
                  ),
                  // Debug widget to test ModelManager
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: const ModelManagerDebugWidget(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Desktop layout: Split-screen (30% controls, 70% summary)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left panel: Controls and audio visualizer (30%)
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.3,
          child: _buildControlsPanel(),
        ),
        // Divider
        const VerticalDivider(width: 1),
        // Right panel: Summary and comments (70%)
        Expanded(
          child: Column(
            children: [
              // Live summary view
              Expanded(
                flex: 7,
                child: _buildSummaryPanel(),
              ),
              // Comments section
              Expanded(
                flex: 3,
                child: _buildCommentsPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tablet layout: Stacked panels with side-by-side in landscape
  Widget _buildTabletLayout() {
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      return _buildDesktopLayout(); // Use desktop layout in landscape
    } else {
      return Column(
        children: [
          // Controls section
          SizedBox(
            height: 200,
            child: _buildControlsPanel(),
          ),
          // Tabbed content
          Expanded(
            child: _buildTabbedContent(),
          ),
        ],
      );
    }
  }

  /// Mobile layout: Single column with tab navigation
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Compact controls
        Container(
          padding: const EdgeInsets.all(16),
          child: _buildCompactControls(),
        ),
        // Tabbed content
        Expanded(
          child: _buildTabbedContent(),
        ),
      ],
    );
  }

  /// Controls panel (audio controls, visualizer, timer, status)
  Widget _buildControlsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Audio controls
          Consumer<MeetingService>(
            builder: (context, meetingService, child) {
              return AudioControlsWidget(
                isRecording:
                    meetingService.recordingState == RecordingState.recording,
                onStartRecording: _handleStartRecording,
                onPauseRecording: _handlePauseRecording,
                onStopRecording: _handleStopRecording,
              );
            },
          ),
          const SizedBox(height: 16),

          // Audio visualizer
          Consumer<MeetingService>(
            builder: (context, meetingService, child) {
              return StreamBuilder(
                stream: meetingService.audioVisualization,
                builder: (context, snapshot) {
                  return Container(
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Audio Visualizer',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Meeting timer
          Consumer<MeetingService>(
            builder: (context, meetingService, child) {
              return MeetingTimerWidget(
                isActive:
                    meetingService.recordingState == RecordingState.recording,
                startTime: meetingService.currentSession?.startTime,
              );
            },
          ),
          const SizedBox(height: 16),

          // Status indicators
          _buildStatusIndicators(),
        ],
      ),
    );
  }

  /// Compact controls for mobile
  Widget _buildCompactControls() {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        final isRecording =
            meetingService.recordingState == RecordingState.recording;

        return Row(
          children: [
            // Main record button
            FloatingActionButton(
              onPressed:
                  isRecording ? _handleStopRecording : _handleStartRecording,
              backgroundColor: isRecording ? Colors.red : Colors.blue,
              child: Icon(
                isRecording ? Icons.stop : Icons.fiber_manual_record,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),

            // Compact timer and status
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Audio Levels',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  MeetingTimerWidget(
                    isActive: isRecording,
                    startTime: meetingService.currentSession?.startTime,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Summary panel with live updates
  Widget _buildSummaryPanel() {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        // Convert SummarySegments to ai_summary.MeetingSummary format for the widget
        final summaries = meetingService.liveSegments.map((segment) {
          return ai_summary.MeetingSummary(
            startTime: meetingService.currentSession?.startTime
                    .add(segment.startTime) ??
                DateTime.now(),
            endTime:
                meetingService.currentSession?.startTime.add(segment.endTime) ??
                    DateTime.now(),
            topic: segment.topic,
            keyPoints: segment.keyPoints,
            actionItems: segment.actionItems
                .map((a) => ai_summary.ActionItem(
                      description: a.description,
                      assignee: a.assignee ?? 'Unassigned',
                      dueDate: a.dueDate,
                      priority: a.priority.toString(),
                    ))
                .toList(),
            participants: segment.speakers.map((s) => s.displayName).toList(),
            language: segment.languages.first,
            confidence: 0.85,
          );
        }).toList();

        return LiveSummaryWidget(
          summaries: summaries,
          speechSegments: meetingService.recentSpeechSegments,
          onSummarySegmentTap: _handleSummarySegmentTap,
        );
      },
    );
  }

  /// Comments panel
  Widget _buildCommentsPanel() {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        return CommentsWidget(
          comments: meetingService.sessionComments,
          onAddComment: _handleAddComment,
          onEditComment: _handleEditComment,
          onDeleteComment: _handleDeleteComment,
        );
      },
    );
  }

  /// Tabbed content for mobile/tablet portrait
  Widget _buildTabbedContent() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.summarize),
              text: 'Summary',
            ),
            Tab(
              icon: Icon(Icons.comment),
              text: 'Comments',
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSummaryPanel(),
              _buildCommentsPanel(),
            ],
          ),
        ),
      ],
    );
  }

  /// Status indicators (audio source, language, model info)
  Widget _buildStatusIndicators() {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audio source
            _buildStatusRow(
              'Audio Source',
              meetingService.selectedAudioSource?.name ?? 'None',
              Icons.volume_up,
            ),
            const SizedBox(height: 8),

            // Processing status
            _buildStatusRow(
              'Status',
              _getStatusText(meetingService.recordingState),
              _getStatusIcon(meetingService.recordingState),
              color: _getStatusColor(meetingService.recordingState),
            ),
            const SizedBox(height: 8),

            // Audio level
            _buildStatusRow(
              'Audio Level',
              '${(meetingService.currentAudioLevel * 100).toInt()}%',
              Icons.graphic_eq,
            ),
          ],
        );
      },
    );
  }

  /// Helper for status rows
  Widget _buildStatusRow(String label, String value, IconData icon,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getStatusText(RecordingState state) {
    switch (state) {
      case RecordingState.recording:
        return 'Recording';
      case RecordingState.paused:
        return 'Paused';
      case RecordingState.stopped:
        return 'Stopped';
    }
  }

  IconData _getStatusIcon(RecordingState state) {
    switch (state) {
      case RecordingState.recording:
        return Icons.circle;
      case RecordingState.paused:
        return Icons.pause_circle_outline;
      case RecordingState.stopped:
        return Icons.circle_outlined;
    }
  }

  Color _getStatusColor(RecordingState state) {
    switch (state) {
      case RecordingState.recording:
        return Colors.red;
      case RecordingState.paused:
        return Colors.orange;
      case RecordingState.stopped:
        return Colors.grey;
    }
  }

  /// Loading screen during initialization
  Widget _buildLoadingScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Initializing meeting services...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            // Show model download progress
            const ModelDownloadProgress(),
          ],
        ),
      ),
    );
  }

  /// Compact download indicator for the app bar
  Widget _buildCompactDownloadIndicator() {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final downloadStates = modelManager.downloadStates;
        final activeDownloads = downloadStates.entries
            .where((entry) => entry.value.isDownloading)
            .toList();

        if (activeDownloads.isEmpty) {
          return const SizedBox.shrink();
        }

        // Calculate overall progress
        double totalProgress = 0.0;
        for (final entry in activeDownloads) {
          totalProgress += entry.value.progress;
        }
        final overallProgress = totalProgress / activeDownloads.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  value: overallProgress,
                  strokeWidth: 2,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Downloading ${activeDownloads.length} model${activeDownloads.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Error bar for status messages
  Widget _buildErrorBar() {
    return Container(
      color: Colors.red,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // Event Handlers

  Future<void> _handleStartRecording() async {
    try {
      final meetingService =
          Provider.of<MeetingService>(context, listen: false);
      final success = await meetingService.startMeeting(title: 'New Meeting');
      if (!success) {
        setState(() {
          _errorMessage =
              'Failed to start recording: ${meetingService.lastError}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error starting recording: $e';
      });
    }
  }

  Future<void> _handlePauseRecording() async {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    await meetingService.pauseMeeting();
  }

  Future<void> _handleStopRecording() async {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    await meetingService.stopMeeting();
  }

  void _handleLanguageChange(String language) {
    // TODO: Implement language change
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Language changed to $language')),
    );
  }

  void _handleExport() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _handleSummarySegmentTap(String segmentId) {
    // TODO: Implement segment-specific actions
  }

  void _handleAddComment(String content, {String? segmentId}) {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    meetingService.addComment(content, segmentId: segmentId);
  }

  void _handleEditComment(String commentId, String newContent) {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    meetingService.updateComment(commentId, newContent);
  }

  void _handleDeleteComment(String commentId) {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    meetingService.deleteComment(commentId);
  }
}
