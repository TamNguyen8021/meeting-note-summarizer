import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/control_panel.dart';
import '../widgets/summary_view.dart';
import '../widgets/comments_section.dart';
import '../../core/enums/recording_state.dart';
import '../../services/meeting_service.dart';
import 'audio_test_screen.dart';

/// Main home screen for the Meeting Summarizer app
/// Provides the primary interface for recording and viewing meeting summaries
/// Implements responsive design for desktop and mobile layouts
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDesktop = false;
  int _selectedTabIndex = 0; // 0 = Summary, 1 = Comments

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize the meeting services
  Future<void> _initializeServices() async {
    try {
      // Use a post-frame callback to ensure the widget is mounted
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final meetingService =
            Provider.of<MeetingService>(context, listen: false);
        final success = await meetingService.initialize();

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  meetingService.lastError ?? 'Failed to initialize services'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _initializeServices,
              ),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing services: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle recording state changes
  Future<void> _onRecordingStateChanged(RecordingState newState) async {
    switch (newState) {
      case RecordingState.recording:
        await _startRecording();
        break;
      case RecordingState.paused:
        await _pauseRecording();
        break;
      case RecordingState.stopped:
        await _stopRecording();
        break;
    }
  }

  /// Start recording implementation
  Future<void> _startRecording() async {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    final success = await meetingService.startMeeting();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(meetingService.lastError ?? 'Failed to start recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Pause recording implementation
  Future<void> _pauseRecording() async {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    final success = await meetingService.pauseMeeting();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(meetingService.lastError ?? 'Failed to pause recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Stop recording implementation
  Future<void> _stopRecording() async {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    final success = await meetingService.stopMeeting();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(meetingService.lastError ?? 'Failed to stop recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle export action
  void _onExportPressed() {
    final meetingService = Provider.of<MeetingService>(context, listen: false);
    final currentSession = meetingService.currentSession;

    if (currentSession != null) {
      // TODO: Implement export functionality
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Summary'),
          content: const Text('Export functionality will be implemented soon.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingService>(
      builder: (context, meetingService, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Determine if we're on desktop or mobile
            _isDesktop = constraints.maxWidth >= 768;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Meeting Summarizer'),
                actions: [
                  // Language indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Chip(
                      label: Text(meetingService.currentLanguage),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  // Export button
                  IconButton(
                    onPressed: _onExportPressed,
                    icon: const Icon(Icons.download),
                    tooltip: 'Export Summary',
                  ),
                ],
              ),
              body: meetingService.isAudioInitialized &&
                      meetingService.isAiInitialized
                  ? (_isDesktop
                      ? _buildDesktopLayout(meetingService)
                      : _buildMobileLayout(meetingService))
                  : _buildLoadingView(meetingService),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AudioTestScreen(),
                    ),
                  );
                },
                child: const Icon(Icons.mic_external_on),
                tooltip: 'Audio Test',
              ),
            );
          },
        );
      },
    );
  }

  /// Build loading view while services initialize
  Widget _buildLoadingView(MeetingService meetingService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            meetingService.lastError ?? 'Initializing services...',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (meetingService.lastError != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeServices,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build desktop layout (split-screen: 30% controls, 70% summary)
  Widget _buildDesktopLayout(MeetingService meetingService) {
    return Row(
      children: [
        // Left panel - Controls (30%)
        Expanded(
          flex: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: ControlPanel(
              recordingState: meetingService.recordingState,
              audioLevel: meetingService.currentAudioLevel,
              elapsedTime: meetingService.currentDuration,
              currentLanguage: meetingService.currentLanguage,
              onRecordingStateChanged: _onRecordingStateChanged,
            ),
          ),
        ),
        // Right panel - Summary and Comments (70%)
        Expanded(
          flex: 70,
          child: Column(
            children: [
              // Summary view
              Expanded(
                child: SummaryView(
                  session: meetingService.currentSession,
                  isLive:
                      meetingService.recordingState == RecordingState.recording,
                ),
              ),
              // Comments section - Fixed height container that allows internal scrolling
              SizedBox(
                height: 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: CommentsSection(
                    session: meetingService.currentSession,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build mobile layout (single column with tab navigation)
  Widget _buildMobileLayout(MeetingService meetingService) {
    return Column(
      children: [
        // Control panel at top
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: ControlPanel(
            recordingState: meetingService.recordingState,
            audioLevel: meetingService.currentAudioLevel,
            elapsedTime: meetingService.currentDuration,
            currentLanguage: meetingService.currentLanguage,
            onRecordingStateChanged: _onRecordingStateChanged,
            isCompact: true, // Mobile-optimized layout
          ),
        ),
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            onTap: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            tabs: const [
              Tab(text: 'Summary', icon: Icon(Icons.summarize)),
              Tab(text: 'Comments', icon: Icon(Icons.comment)),
            ],
          ),
        ),
        // Content area
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              // Summary tab
              SummaryView(
                session: meetingService.currentSession,
                isLive:
                    meetingService.recordingState == RecordingState.recording,
              ),
              // Comments tab
              CommentsSection(
                session: meetingService.currentSession,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
