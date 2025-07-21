import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_service.dart';
import '../../core/audio/audio_source.dart';

/// Test screen for audio capture functionality
/// Allows testing of real-time audio capture and processing
class AudioTestScreen extends StatefulWidget {
  const AudioTestScreen({Key? key}) : super(key: key);

  @override
  State<AudioTestScreen> createState() => _AudioTestScreenState();
}

class _AudioTestScreenState extends State<AudioTestScreen> {
  Timer? _uiUpdateTimer;
  List<AudioSource> _availableSources = [];
  AudioSource? _selectedSource;
  bool _isCapturing = false;
  double _currentAudioLevel = 0.0;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _loadAudioSources();
    // Start UI update timer
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isCapturing) {
        final audioService = context.read<AudioService>();
        setState(() {
          _currentAudioLevel = audioService.currentAudioLevel;
        });
      }
    });
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAudioSources() async {
    final audioService = context.read<AudioService>();
    try {
      await audioService.initialize();
      await audioService.refreshAudioSources();
      setState(() {
        _availableSources = audioService.availableSources;
        if (_availableSources.isNotEmpty) {
          _selectedSource = _availableSources.first;
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading sources: $e';
      });
    }
  }

  Future<void> _toggleCapture() async {
    final audioService = context.read<AudioService>();

    if (_isCapturing) {
      // Stop capture
      await audioService.stopCapture();
      setState(() {
        _isCapturing = false;
        _currentAudioLevel = 0.0;
        _status = 'Stopped';
      });
    } else {
      // Start capture
      if (_selectedSource != null) {
        try {
          await audioService.selectAudioSource(_selectedSource!);
          final success = await audioService.startCapture();

          if (success) {
            setState(() {
              _isCapturing = true;
              _status = 'Capturing from ${_selectedSource!.name}';
            });
          } else {
            setState(() {
              _status = 'Failed to start capture';
            });
          }
        } catch (e) {
          setState(() {
            _status = 'Error starting capture: $e';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Capture Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_status),
                      const SizedBox(height: 8),
                      Text(
                          'Audio Level: ${(_currentAudioLevel * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Audio Level Indicator
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audio Level',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _currentAudioLevel,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _currentAudioLevel > 0.8
                              ? Colors.red
                              : _currentAudioLevel > 0.5
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Audio Source Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audio Source',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_availableSources.isEmpty)
                        const Text('No audio sources available')
                      else
                        DropdownButton<AudioSource>(
                          value: _selectedSource,
                          isExpanded: true,
                          onChanged: _isCapturing
                              ? null
                              : (AudioSource? source) {
                                  setState(() {
                                    _selectedSource = source;
                                  });
                                },
                          items: _availableSources.map((AudioSource source) {
                            return DropdownMenuItem<AudioSource>(
                              value: source,
                              child: Text('${source.name} (${source.type})'),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Control Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _selectedSource == null ? null : _toggleCapture,
                      icon: Icon(_isCapturing ? Icons.stop : Icons.play_arrow),
                      label:
                          Text(_isCapturing ? 'Stop Capture' : 'Start Capture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isCapturing ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _loadAudioSources,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Configuration Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audio Configuration',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Sample Rate: 16,000 Hz'),
                      const Text('Channels: 1 (Mono)'),
                      const Text('Bit Depth: 16-bit'),
                      const Text('Buffer Size: 100ms'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
