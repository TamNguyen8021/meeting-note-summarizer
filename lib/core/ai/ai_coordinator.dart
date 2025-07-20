import 'dart:async';
import 'package:flutter/foundation.dart';

import 'speech_recognition_interface.dart';
import 'summarization_interface.dart';
import 'enhanced_model_manager.dart';
import 'whisper_speech_recognition.dart';
import 'llama_summarization.dart';
import '../../services/mock_speech_recognition.dart';
import '../../services/mock_summarization.dart';

/// Advanced AI coordinator that manages real model loading and switching
/// Provides intelligent model selection based on device capabilities and user preferences
class AiCoordinator extends ChangeNotifier {
  final ModelManager _modelManager;

  // Active AI implementations
  SpeechRecognitionInterface? _activeSpeechRecognition;
  SummarizationInterface? _activeSummarization;

  // Available implementations
  final Map<String, SpeechRecognitionInterface> _speechRecognitionImpls = {};
  final Map<String, SummarizationInterface> _summarizationImpls = {};

  // State tracking
  bool _isInitialized = false;
  bool _isModelSwitching = false;
  String? _lastError;

  // Current configuration
  String _currentSpeechModel = 'whisper-tiny';
  String _currentSummaryModel = 'tinyllama-q4';
  bool _useMockImplementations = true;

  // Performance monitoring
  final List<ModelPerformanceMetric> _performanceHistory = [];
  DateTime? _lastModelSwitch;

  AiCoordinator({
    ModelManager? modelManager,
    bool initialMockMode = true,
  })  : _modelManager = modelManager ?? ModelManager(),
        _useMockImplementations = initialMockMode;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isModelSwitching => _isModelSwitching;
  String? get lastError => _lastError;
  String get currentSpeechModel => _currentSpeechModel;
  String get currentSummaryModel => _currentSummaryModel;
  bool get useMockImplementations => _useMockImplementations;

  SpeechRecognitionInterface? get speechRecognition => _activeSpeechRecognition;
  SummarizationInterface? get summarization => _activeSummarization;

  List<ModelPerformanceMetric> get performanceHistory =>
      List.unmodifiable(_performanceHistory);

  /// Initialize the AI coordinator
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _lastError = null;

      // Initialize model manager first
      final modelSuccess = await _modelManager.initialize();
      if (!modelSuccess) {
        debugPrint('ModelManager initialization failed, continuing with mocks');
        _useMockImplementations = true;
      }

      // Initialize implementations
      await _initializeImplementations();

      // Setup active implementations
      await _setupActiveImplementations();

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize AI coordinator: $e';
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  /// Initialize all available AI implementations
  Future<void> _initializeImplementations() async {
    // Mock implementations (always available)
    _speechRecognitionImpls['mock'] = MockSpeechRecognition();
    _summarizationImpls['mock'] = MockSummarization();

    // Real implementations (when models are available)
    if (!_useMockImplementations && _modelManager.isInitialized) {
      try {
        // Whisper speech recognition
        for (final modelId in [
          'whisper-tiny',
          'whisper-base',
          'whisper-small'
        ]) {
          if (_modelManager.availableModels.containsKey(modelId)) {
            final whisper = WhisperSpeechRecognition(
              modelManager: _modelManager,
            );
            _speechRecognitionImpls[modelId] = whisper;
          }
        }

        // Llama summarization
        for (final modelId in [
          'tinyllama-q4',
          'llama-3.2-1b-q4',
          'llama-3.2-3b-q4',
          'phi-3-mini-q4'
        ]) {
          if (_modelManager.availableModels.containsKey(modelId)) {
            final llama = LlamaSummarization(
              modelManager: _modelManager,
            );
            _summarizationImpls[modelId] = llama;
          }
        }
      } catch (e) {
        debugPrint('Error initializing real implementations: $e');
        _useMockImplementations = true;
      }
    }
  }

  /// Setup active implementations based on current configuration
  Future<void> _setupActiveImplementations() async {
    if (_useMockImplementations) {
      _activeSpeechRecognition = _speechRecognitionImpls['mock'];
      _activeSummarization = _summarizationImpls['mock'];
    } else {
      // Use configured models if available, fallback to mocks
      _activeSpeechRecognition = _speechRecognitionImpls[_currentSpeechModel] ??
          _speechRecognitionImpls['mock'];
      _activeSummarization = _summarizationImpls[_currentSummaryModel] ??
          _summarizationImpls['mock'];
    }

    // Initialize active implementations
    if (_activeSpeechRecognition != null) {
      await _activeSpeechRecognition!.initialize();
    }
    if (_activeSummarization != null) {
      await _activeSummarization!.initialize();
    }
  }

  /// Switch to real AI implementations (download models if needed)
  Future<bool> switchToRealImplementations() async {
    if (!_modelManager.isInitialized) {
      _lastError = 'Model manager not initialized';
      return false;
    }

    _isModelSwitching = true;
    notifyListeners();

    try {
      // Ensure required models are downloaded
      final requiredModels = [_currentSpeechModel, _currentSummaryModel];

      for (final modelId in requiredModels) {
        if (!_modelManager.loadedModels.containsKey(modelId)) {
          debugPrint('Downloading required model: $modelId');
          final downloadSuccess = await _modelManager.downloadModel(modelId);
          if (!downloadSuccess) {
            _lastError = 'Failed to download model: $modelId';
            _isModelSwitching = false;
            notifyListeners();
            return false;
          }
        }
      }

      // Re-initialize implementations with real models
      _useMockImplementations = false;
      await _initializeImplementations();
      await _setupActiveImplementations();

      _lastModelSwitch = DateTime.now();
      _isModelSwitching = false;
      notifyListeners();

      debugPrint('Successfully switched to real AI implementations');
      return true;
    } catch (e) {
      _lastError = 'Error switching to real implementations: $e';
      _isModelSwitching = false;
      notifyListeners();
      return false;
    }
  }

  /// Switch to mock AI implementations (for testing/demo)
  Future<bool> switchToMockImplementations() async {
    _isModelSwitching = true;
    notifyListeners();

    try {
      // Switch to mock mode
      _useMockImplementations = true;
      await _initializeImplementations();
      await _setupActiveImplementations();

      _lastModelSwitch = DateTime.now();
      _isModelSwitching = false;
      notifyListeners();

      debugPrint('Successfully switched to mock AI implementations');
      return true;
    } catch (e) {
      _lastError = 'Error switching to mock implementations: $e';
      _isModelSwitching = false;
      notifyListeners();
      return false;
    }
  }

  /// Switch speech recognition model
  Future<bool> switchSpeechModel(String modelId) async {
    if (!_modelManager.availableModels.containsKey(modelId)) {
      _lastError = 'Speech model not available: $modelId';
      return false;
    }

    final oldModel = _currentSpeechModel;
    _isModelSwitching = true;
    notifyListeners();

    try {
      // Download model if needed
      if (!_modelManager.loadedModels.containsKey(modelId)) {
        final downloadSuccess = await _modelManager.downloadModel(modelId);
        if (!downloadSuccess) {
          _lastError = 'Failed to download speech model: $modelId';
          _isModelSwitching = false;
          notifyListeners();
          return false;
        }
      }

      // Load model instance
      final loadSuccess = await _modelManager.loadModelInstance(modelId);
      if (!loadSuccess) {
        _lastError = 'Failed to load speech model instance: $modelId';
        _isModelSwitching = false;
        notifyListeners();
        return false;
      }

      // Create new implementation
      if (!_speechRecognitionImpls.containsKey(modelId)) {
        final whisper = WhisperSpeechRecognition(
          modelManager: _modelManager,
        );
        await whisper.initialize();
        _speechRecognitionImpls[modelId] = whisper;
      }

      // Switch active implementation
      _activeSpeechRecognition = _speechRecognitionImpls[modelId];
      _currentSpeechModel = modelId;

      // Unload old model to save memory
      _modelManager.unloadModelInstance(oldModel);

      _recordModelSwitch(oldModel, modelId, 'speech');
      _isModelSwitching = false;
      notifyListeners();

      debugPrint('Switched speech model from $oldModel to $modelId');
      return true;
    } catch (e) {
      _lastError = 'Error switching speech model: $e';
      _isModelSwitching = false;
      notifyListeners();
      return false;
    }
  }

  /// Switch summarization model
  Future<bool> switchSummarizationModel(String modelId) async {
    if (!_modelManager.availableModels.containsKey(modelId)) {
      _lastError = 'Summarization model not available: $modelId';
      return false;
    }

    final oldModel = _currentSummaryModel;
    _isModelSwitching = true;
    notifyListeners();

    try {
      // Download model if needed
      if (!_modelManager.loadedModels.containsKey(modelId)) {
        final downloadSuccess = await _modelManager.downloadModel(modelId);
        if (!downloadSuccess) {
          _lastError = 'Failed to download summarization model: $modelId';
          _isModelSwitching = false;
          notifyListeners();
          return false;
        }
      }

      // Load model instance
      final loadSuccess = await _modelManager.loadModelInstance(modelId);
      if (!loadSuccess) {
        _lastError = 'Failed to load summarization model instance: $modelId';
        _isModelSwitching = false;
        notifyListeners();
        return false;
      }

      // Create new implementation
      if (!_summarizationImpls.containsKey(modelId)) {
        final llama = LlamaSummarization(
          modelManager: _modelManager,
        );
        await llama.initialize();
        _summarizationImpls[modelId] = llama;
      }

      // Switch active implementation
      _activeSummarization = _summarizationImpls[modelId];
      _currentSummaryModel = modelId;

      // Unload old model to save memory
      _modelManager.unloadModelInstance(oldModel);

      _recordModelSwitch(oldModel, modelId, 'summarization');
      _isModelSwitching = false;
      notifyListeners();

      debugPrint('Switched summarization model from $oldModel to $modelId');
      return true;
    } catch (e) {
      _lastError = 'Error switching summarization model: $e';
      _isModelSwitching = false;
      notifyListeners();
      return false;
    }
  }

  /// Get recommended models based on device capabilities
  Map<String, List<String>> getRecommendedModels() {
    final recommendations = <String, List<String>>{
      'speech': <String>[],
      'summarization': <String>[],
    };

    // Get available storage and memory constraints
    final availableModels = _modelManager.availableModels;

    // Speech recognition recommendations
    if (availableModels.containsKey('whisper-tiny')) {
      recommendations['speech']!.add('whisper-tiny');
    }
    if (availableModels.containsKey('whisper-base')) {
      recommendations['speech']!.add('whisper-base');
    }
    if (availableModels.containsKey('whisper-small')) {
      recommendations['speech']!.add('whisper-small');
    }

    // Summarization recommendations
    if (availableModels.containsKey('tinyllama-q4')) {
      recommendations['summarization']!.add('tinyllama-q4');
    }
    if (availableModels.containsKey('llama-3.2-1b-q4')) {
      recommendations['summarization']!.add('llama-3.2-1b-q4');
    }
    if (availableModels.containsKey('phi-3-mini-q4')) {
      recommendations['summarization']!.add('phi-3-mini-q4');
    }

    return recommendations;
  }

  /// Get model switching statistics
  Map<String, dynamic> getModelStats() {
    return {
      'currentSpeechModel': _currentSpeechModel,
      'currentSummaryModel': _currentSummaryModel,
      'useMockImplementations': _useMockImplementations,
      'availableImplementations': {
        'speech': _speechRecognitionImpls.keys.toList(),
        'summarization': _summarizationImpls.keys.toList(),
      },
      'lastModelSwitch': _lastModelSwitch?.toIso8601String(),
      'performanceHistory': _performanceHistory.length,
    };
  }

  /// Record model switch for performance tracking
  void _recordModelSwitch(String oldModel, String newModel, String type) {
    _performanceHistory.add(ModelPerformanceMetric(
      timestamp: DateTime.now(),
      modelId: newModel,
      type: type,
      event: 'switch',
      previousModel: oldModel,
    ));

    // Keep only last 50 metrics
    if (_performanceHistory.length > 50) {
      _performanceHistory.removeAt(0);
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    // Dispose all implementations
    for (final impl in _speechRecognitionImpls.values) {
      impl.dispose();
    }
    for (final impl in _summarizationImpls.values) {
      impl.dispose();
    }

    _speechRecognitionImpls.clear();
    _summarizationImpls.clear();
    _activeSpeechRecognition = null;
    _activeSummarization = null;

    super.dispose();
  }
}

/// Performance metric for model usage tracking
class ModelPerformanceMetric {
  final DateTime timestamp;
  final String modelId;
  final String type; // 'speech' or 'summarization'
  final String event; // 'switch', 'load', 'unload'
  final String? previousModel;
  final Map<String, dynamic>? metadata;

  const ModelPerformanceMetric({
    required this.timestamp,
    required this.modelId,
    required this.type,
    required this.event,
    this.previousModel,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'modelId': modelId,
      'type': type,
      'event': event,
      'previousModel': previousModel,
      'metadata': metadata,
    };
  }
}
