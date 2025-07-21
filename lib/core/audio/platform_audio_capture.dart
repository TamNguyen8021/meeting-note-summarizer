import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

import 'audio_capture_interface.dart';
import 'audio_chunk.dart';
import 'audio_source.dart';

class PlatformAudioCapture implements AudioCaptureInterface {
  final AudioRecorder _recorder = AudioRecorder();

  // Stream controllers
  StreamController<AudioChunk>? _audioStreamController;
  StreamController<List<AudioSource>>? _sourcesStreamController;
  StreamController<double>? _levelStreamController;

  Timer? _chunkTimer;
  bool _isCapturing = false;
  AudioSource? _currentSource;
  final List<AudioSource> _availableSources = [
    const AudioSource(
      id: 'default_microphone',
      name: 'Default Microphone',
      type: AudioSourceType.microphone,
    ),
    // Remove system audio since this implementation can't actually capture it
  ];

  // Audio configuration
  final Map<String, dynamic> _audioConfig = {
    'sampleRate': 16000,
    'channels': 1,
    'bitsPerSample': 16,
    'bufferSizeMs': 100,
  };

  @override
  Stream<AudioChunk> get audioStream {
    _audioStreamController ??= StreamController<AudioChunk>.broadcast();
    return _audioStreamController!.stream;
  }

  @override
  Stream<List<AudioSource>> get availableSourcesStream {
    _sourcesStreamController ??=
        StreamController<List<AudioSource>>.broadcast();
    return _sourcesStreamController!.stream;
  }

  @override
  Stream<double> get audioLevelStream {
    _levelStreamController ??= StreamController<double>.broadcast();
    return _levelStreamController!.stream;
  }

  @override
  AudioSource? get currentSource => _currentSource;

  @override
  bool get isCapturing => _isCapturing;

  @override
  bool get supportsSystemAudio =>
      false; // This implementation only supports microphone via record package

  @override
  Map<String, dynamic> get audioConfig => _audioConfig;

  @override
  Future<bool> initialize() async {
    try {
      // Check permissions
      bool hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        // The record package will handle permission requests automatically
        hasPermission = await _recorder.hasPermission();
      }

      // Emit initial sources
      _sourcesStreamController?.add(_availableSources);

      return hasPermission;
    } catch (e) {
      print('Error initializing audio capture: $e');
      return false;
    }
  }

  @override
  Future<List<AudioSource>> getAvailableSources() async {
    return _availableSources;
  }

  @override
  Future<bool> selectSource(AudioSource source) async {
    if (_availableSources.contains(source)) {
      _currentSource = source;
      return true;
    }
    return false;
  }

  @override
  Future<bool> startCapture() async {
    if (_isCapturing) return true;

    try {
      // Check permission first
      if (!await _recorder.hasPermission()) {
        print('No microphone permission');
        return false;
      }

      // For real-time audio capture, we'll use the amplitude stream
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: _audioConfig['sampleRate'],
          numChannels: _audioConfig['channels'],
        ),
        path: 'temp_audio.wav', // Temporary file for recording
      );

      _isCapturing = true;
      _startAudioLevelMonitoring();
      print('Audio capture started successfully');
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  void _startAudioLevelMonitoring() {
    final bufferSizeMs = _audioConfig['bufferSizeMs'] as int;

    _chunkTimer = Timer.periodic(
      Duration(milliseconds: bufferSizeMs),
      (timer) async {
        if (_isCapturing &&
            _audioStreamController != null &&
            !_audioStreamController!.isClosed) {
          // Get amplitude level from recorder
          final amplitude = await _recorder.getAmplitude();
          double level = 0.0;

          if (amplitude.current > -50.0) {
            // Convert dB to normalized level (0.0 - 1.0)
            level = (amplitude.current + 50.0) / 50.0;
            level = level.clamp(0.0, 1.0);
          }

          // Create a simple audio chunk for visualization
          // Note: This is simplified - real audio data would come from streaming
          final sampleRate = _audioConfig['sampleRate'] as int;
          final channels = _audioConfig['channels'] as int;
          final bitsPerSample = _audioConfig['bitsPerSample'] as int;

          final chunkSize =
              (sampleRate * channels * (bitsPerSample ~/ 8) * bufferSizeMs) ~/
                  1000;
          final audioData = Uint8List(chunkSize);

          final chunk = AudioChunk(
            data: audioData,
            timestamp: DateTime.now(),
            duration: Duration(milliseconds: bufferSizeMs),
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: bitsPerSample,
            level: level,
          );

          _audioStreamController!.add(chunk);
          _levelStreamController?.add(level);
        }
      },
    );
  }

  @override
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _recorder.stop();
      _isCapturing = false;
      _chunkTimer?.cancel();
      _chunkTimer = null;
      _levelStreamController?.add(0.0);
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  @override
  Future<void> pauseCapture() async {
    await _recorder.pause();
  }

  @override
  Future<bool> resumeCapture() async {
    try {
      await _recorder.resume();
      return true;
    } catch (e) {
      print('Error resuming recording: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await stopCapture();
    await _audioStreamController?.close();
    await _sourcesStreamController?.close();
    await _levelStreamController?.close();
    _audioStreamController = null;
    _sourcesStreamController = null;
    _levelStreamController = null;
    _recorder.dispose();
  }
}
