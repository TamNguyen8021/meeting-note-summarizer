import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ai/ai_coordinator.dart';
import '../../core/ai/enhanced_model_manager.dart';
import '../../services/meeting_service.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/ai_status_widget.dart';

/// Real-time meeting dashboard showing AI processing status and live metrics
class MeetingDashboard extends StatefulWidget {
  const MeetingDashboard({super.key});

  @override
  State<MeetingDashboard> createState() => _MeetingDashboardState();
}

class _MeetingDashboardState extends State<MeetingDashboard>
    with TickerProviderStateMixin {
  late AnimationController _dashboardController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _dashboardController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dashboardController, curve: Curves.easeInOut),
    );
    _dashboardController.forward();
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => _refreshDashboard(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: _buildDashboardContent(),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Consumer3<MeetingService, AiCoordinator, ModelManager>(
      builder: (context, meetingService, aiCoordinator, modelManager, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session overview
              _buildSessionOverview(meetingService),
              const SizedBox(height: 24),

              // Real-time metrics
              _buildRealtimeMetrics(meetingService, aiCoordinator),
              const SizedBox(height: 24),

              // AI Status and Performance
              _buildAiPerformanceSection(aiCoordinator, modelManager),
              const SizedBox(height: 24),

              // Processing pipeline status
              _buildProcessingPipeline(meetingService, aiCoordinator),
              const SizedBox(height: 24),

              // Model analytics
              _buildModelAnalytics(modelManager),
            ],
          ),
        );
      },
    );
  }

  /// Session overview card
  Widget _buildSessionOverview(MeetingService meetingService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.meeting_room,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Meeting Session',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Status',
                    _getRecordingStatusText(meetingService.recordingState),
                    _getRecordingStatusColor(meetingService.recordingState),
                    Icons.radio_button_checked,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Duration',
                    _formatDuration(meetingService.currentDuration),
                    Colors.blue,
                    Icons.timer,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Language',
                    meetingService.currentLanguage.toUpperCase(),
                    Colors.green,
                    Icons.language,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Real-time metrics display
  Widget _buildRealtimeMetrics(
      MeetingService meetingService, AiCoordinator aiCoordinator) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Real-time Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Audio visualization
            SizedBox(
              height: 120,
              child: AudioVisualizer(
                level: meetingService.currentAudioLevel,
                quality: 0.85, // Simulated quality
                isRecording: meetingService.recordingState
                    .toString()
                    .contains('recording'),
                isProcessing: aiCoordinator.isModelSwitching,
                currentModel: aiCoordinator.currentSpeechModel,
                primaryColor: Theme.of(context).primaryColor,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Audio Level',
                    '${(meetingService.currentAudioLevel * 100).toInt()}%',
                    _getAudioLevelColor(meetingService.currentAudioLevel),
                    Icons.volume_up,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Processing',
                    aiCoordinator.isModelSwitching ? 'Active' : 'Ready',
                    aiCoordinator.isModelSwitching
                        ? Colors.orange
                        : Colors.green,
                    Icons.settings,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Segments',
                    '${meetingService.liveSegments.length}',
                    Colors.purple,
                    Icons.text_snippet,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// AI Performance section
  Widget _buildAiPerformanceSection(
      AiCoordinator aiCoordinator, ModelManager modelManager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Performance',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        // AI Status widget with expanded details
        AiStatusWidget(
          showDetailedStats: true,
          allowModelSwitching: true,
        ),
      ],
    );
  }

  /// Processing pipeline status
  Widget _buildProcessingPipeline(
      MeetingService meetingService, AiCoordinator aiCoordinator) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Processing Pipeline',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildPipelineStep(
              'Audio Capture',
              meetingService.isAudioInitialized,
              'Capturing system audio',
              Icons.mic,
            ),
            const SizedBox(height: 12),
            _buildPipelineStep(
              'Speech Recognition',
              meetingService.recordingState.toString().contains('recording') &&
                  !aiCoordinator.useMockImplementations,
              'Converting speech to text',
              Icons.hearing,
            ),
            const SizedBox(height: 12),
            _buildPipelineStep(
              'Text Summarization',
              meetingService.liveSegments.isNotEmpty,
              'Generating meeting summary',
              Icons.summarize,
            ),
            const SizedBox(height: 12),
            _buildPipelineStep(
              'Export Ready',
              meetingService.recentSummaries.isNotEmpty,
              'Ready for export',
              Icons.file_download,
            ),
          ],
        ),
      ),
    );
  }

  /// Individual pipeline step
  Widget _buildPipelineStep(
      String title, bool isActive, String description, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.green : Colors.grey.withOpacity(0.3),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? null : Colors.grey,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.grey[600] : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        if (isActive)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
          ),
      ],
    );
  }

  /// Model analytics section
  Widget _buildModelAnalytics(ModelManager modelManager) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: modelManager.getCurrentStorageSize(),
              builder: (context, snapshot) {
                final used = snapshot.data ?? 0;
                final total = ModelManager.maxTotalSizeBytes;
                final percentage = (used / total * 100);

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            'Storage Used',
                            _formatFileSize(used),
                            _getStorageColor(percentage),
                            Icons.storage,
                          ),
                        ),
                        Expanded(
                          child: _buildMetricItem(
                            'Available Models',
                            '${modelManager.availableModels.length}',
                            Colors.blue,
                            Icons.inventory,
                          ),
                        ),
                        Expanded(
                          child: _buildMetricItem(
                            'Downloaded',
                            '${modelManager.loadedModels.length}',
                            Colors.green,
                            Icons.download_done,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Storage progress bar
                    LinearProgressIndicator(
                      value: used / total,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStorageColor(percentage),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      '${percentage.toStringAsFixed(1)}% of ${_formatFileSize(total)} used',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Individual metric item
  Widget _buildMetricItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper methods

  void _refreshDashboard() {
    _dashboardController.reset();
    _dashboardController.forward();
  }

  String _getRecordingStatusText(recordingState) {
    switch (recordingState.toString()) {
      case 'RecordingState.recording':
        return 'Recording';
      case 'RecordingState.paused':
        return 'Paused';
      case 'RecordingState.stopped':
        return 'Stopped';
      default:
        return 'Unknown';
    }
  }

  Color _getRecordingStatusColor(recordingState) {
    switch (recordingState.toString()) {
      case 'RecordingState.recording':
        return Colors.green;
      case 'RecordingState.paused':
        return Colors.orange;
      case 'RecordingState.stopped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getAudioLevelColor(double level) {
    if (level >= 0.7) return Colors.green;
    if (level >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Color _getStorageColor(double percentage) {
    if (percentage >= 80) return Colors.red;
    if (percentage >= 60) return Colors.orange;
    return Colors.green;
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
