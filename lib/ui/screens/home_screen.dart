import 'package:flutter/material.dart';
import '../widgets/control_panel.dart';
import '../widgets/summary_view.dart';
import '../widgets/comments_section.dart';
import '../../core/models/meeting_session.dart';
import '../../core/enums/recording_state.dart';

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
  // Current meeting session state
  MeetingSession? _currentSession;
  RecordingState _recordingState = RecordingState.stopped;
  double _audioLevel = 0.0;
  String _currentLanguage = 'EN';
  Duration _elapsedTime = Duration.zero;

  // UI state
  bool _isDesktop = false;
  int _selectedTabIndex = 0; // 0 = Summary, 1 = Comments

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize a new meeting session
  void _initializeSession() {
    setState(() {
      _currentSession = MeetingSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Meeting ${DateTime.now().toLocal()}',
        startTime: DateTime.now(),
      );
    });
  }

  /// Handle recording state changes
  void _onRecordingStateChanged(RecordingState newState) {
    setState(() {
      _recordingState = newState;
    });

    // TODO: Implement actual recording logic
    switch (newState) {
      case RecordingState.recording:
        _startRecording();
        break;
      case RecordingState.paused:
        _pauseRecording();
        break;
      case RecordingState.stopped:
        _stopRecording();
        break;
    }
  }

  /// Start recording implementation
  void _startRecording() {
    // TODO: Implement audio capture start
    print('Starting recording...');
  }

  /// Pause recording implementation
  void _pauseRecording() {
    // TODO: Implement audio capture pause
    print('Pausing recording...');
  }

  /// Stop recording implementation
  void _stopRecording() {
    // TODO: Implement audio capture stop
    print('Stopping recording...');
  }

  /// Handle export action
  void _onExportPressed() {
    if (_currentSession != null) {
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
                  label: Text(_currentLanguage),
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
          body: _isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  /// Build desktop layout (split-screen: 30% controls, 70% summary)
  Widget _buildDesktopLayout() {
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
              recordingState: _recordingState,
              audioLevel: _audioLevel,
              elapsedTime: _elapsedTime,
              currentLanguage: _currentLanguage,
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
                  session: _currentSession,
                  isLive: _recordingState == RecordingState.recording,
                ),
              ),
              // Comments section - Fixed height container that allows internal scrolling
              SizedBox(
                height:
                    180, // Fixed height instead of flex to allow proper scrolling
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
                    session: _currentSession,
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
  Widget _buildMobileLayout() {
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
            recordingState: _recordingState,
            audioLevel: _audioLevel,
            elapsedTime: _elapsedTime,
            currentLanguage: _currentLanguage,
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
                session: _currentSession,
                isLive: _recordingState == RecordingState.recording,
              ),
              // Comments tab
              CommentsSection(
                session: _currentSession,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
