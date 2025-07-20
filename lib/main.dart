import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/themes/app_theme.dart';
import 'services/meeting_service.dart';
import 'services/audio_service.dart';
import 'core/ai/enhanced_model_manager.dart';
import 'core/ai/ai_coordinator.dart';
import 'core/ai/enhanced_ai_service.dart';

void main() {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MeetingSummarizerApp());
}

/// Main application widget for Meeting Summarizer
/// Provides the root MaterialApp with theme and routing configuration
class MeetingSummarizerApp extends StatelessWidget {
  const MeetingSummarizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Audio Service
        ChangeNotifierProvider(
          create: (context) => AudioService(),
          lazy: false,
        ),
        // AI Model Management
        ChangeNotifierProvider(
          create: (context) => ModelManager()..initialize(),
          lazy: false,
        ),
        // AI Coordinator
        ChangeNotifierProvider(
          create: (context) => AiCoordinator(),
          lazy: false,
        ),
        // Enhanced AI Service
        ChangeNotifierProvider(
          create: (context) => EnhancedAiService(),
          lazy: false,
        ),
        // Meeting Service
        ChangeNotifierProvider(
          create: (context) => MeetingService(),
          lazy: false, // Initialize immediately
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
