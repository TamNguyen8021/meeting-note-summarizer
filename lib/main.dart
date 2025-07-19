import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'ui/screens/home_screen.dart';
import 'ui/themes/app_theme.dart';

void main() {
  runApp(const MeetingSummarizerApp());
}

/// Main application widget for Meeting Summarizer
/// Provides the root MaterialApp with theme and routing configuration
class MeetingSummarizerApp extends StatelessWidget {
  const MeetingSummarizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meeting Summarizer',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: kDebugMode,
    );
  }
}
