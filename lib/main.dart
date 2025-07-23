import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ui/screens/home_screen.dart';
import 'ui/themes/app_theme.dart';
import 'services/meeting_service.dart';
import 'services/audio_service.dart';
import 'core/ai/ai_coordinator.dart';
import 'core/ai/enhanced_model_manager.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Request microphone permission immediately
  await _requestMicrophonePermission();

  runApp(const MeetingSummarizerApp());
}

/// Request microphone permission at app startup
Future<void> _requestMicrophonePermission() async {
  try {
    if (kDebugMode) {
      print('Requesting microphone permission at startup...');
    }

    // Request microphone permission directly
    final status = await Permission.microphone.request();

    if (kDebugMode) {
      print('Microphone permission status: $status');
    }

    if (status == PermissionStatus.granted) {
      if (kDebugMode) {
        print('Microphone permission granted successfully');
      }
    } else {
      if (kDebugMode) {
        print('Microphone permission denied or restricted');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Failed to request microphone permission at startup: $e');
    }
  }
}

/// Main application widget for Meeting Summarizer
/// Provides the root MaterialApp with theme and routing configuration
class MeetingSummarizerApp extends StatelessWidget {
  const MeetingSummarizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Model Manager (base dependency)
        ChangeNotifierProvider(
          create: (context) => ModelManager(),
          lazy: false,
        ),
        // AI Coordinator
        ChangeNotifierProvider(
          create: (context) => AiCoordinator(),
          lazy: false,
        ),
        // Audio Service
        ChangeNotifierProvider(
          create: (context) => AudioService(),
          lazy: false,
        ),
        // Meeting Service (full functionality)
        ChangeNotifierProxyProvider<AudioService, MeetingService>(
          create: (context) => MeetingService(),
          update: (context, audioService, meetingService) {
            // The MeetingService will create its own AudioService if none provided
            return meetingService ?? MeetingService(audioService: audioService);
          },
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'Meeting Summarizer',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: kDebugMode,
      ),
    );
  }
}
