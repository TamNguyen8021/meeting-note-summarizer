import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ai/enhanced_model_manager.dart';
import '../../core/ai/ai_coordinator.dart';

/// Advanced model management screen with real-time monitoring and switching capabilities
class ModelManagementScreen extends StatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  State<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends State<ModelManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedModelType = 'speechRecognition';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Model Management'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Models', icon: Icon(Icons.storage)),
            Tab(text: 'Active', icon: Icon(Icons.play_circle)),
            Tab(text: 'Downloads', icon: Icon(Icons.download)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModelsTab(),
          _buildActiveModelsTab(),
          _buildDownloadsTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  /// Available models tab
  Widget _buildModelsTab() {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        if (!modelManager.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Column(
          children: [
            // Model type filter
            _buildModelTypeFilter(),

            // Models list
            Expanded(
              child: _buildModelsList(modelManager),
            ),
          ],
        );
      },
    );
  }

  /// Model type filter
  Widget _buildModelTypeFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'speechRecognition',
                  label: Text('Speech'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: 'textSummarization',
                  label: Text('Summary'),
                  icon: Icon(Icons.summarize),
                ),
                ButtonSegment(
                  value: 'speakerIdentification',
                  label: Text('Speaker'),
                  icon: Icon(Icons.person),
                ),
              ],
              selected: {_selectedModelType},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedModelType = selection.first;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Models list
  Widget _buildModelsList(ModelManager modelManager) {
    final models = modelManager.availableModels.values
        .where((model) => model.type.toString().contains(_selectedModelType))
        .toList();

    if (models.isEmpty) {
      return Center(
        child: Text(
          'No $_selectedModelType models available',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        return _buildModelCard(model, modelManager);
      },
    );
  }

  /// Individual model card
  Widget _buildModelCard(ModelInfo model, ModelManager modelManager) {
    final downloadState = modelManager.downloadStates[model.id];
    final isDownloading = downloadState?.isDownloading ?? false;
    final hasDownloadState = downloadState != null;

    // A model should only be considered downloaded if:
    // 1. It's marked as downloaded AND
    // 2. It's not currently downloading AND
    // 3. There's no active download state OR the download state is completed
    // 4. If there's a download state, progress must be 1.0 and completed must be true
    final isActuallyDownloaded = model.isDownloaded &&
        !isDownloading &&
        (!hasDownloadState ||
            (downloadState.isCompleted && downloadState.progress >= 1.0));

    // Debug logging to help diagnose the issue
    if (model.id == 'whisper-tiny') {
      debugPrint('=== Whisper Tiny Status Debug ===');
      debugPrint('  model.isDownloaded: ${model.isDownloaded}');
      debugPrint('  isDownloading: $isDownloading');
      debugPrint('  hasDownloadState: $hasDownloadState');
      debugPrint('  downloadState: ${downloadState?.toString()}');
      debugPrint('  isActuallyDownloaded: $isActuallyDownloaded');
      debugPrint('================================');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: _buildModelIcon(model.type),
        title: Text(
          model.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.description),
            const SizedBox(height: 4),
            _buildModelMetadata(model),
          ],
        ),
        trailing: _buildModelActions(
            model, modelManager, isActuallyDownloaded, isDownloading),
        children: [
          _buildModelDetails(model),
        ],
      ),
    );
  }

  /// Model type icon
  Widget _buildModelIcon(ModelType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case ModelType.speechRecognition:
        iconData = Icons.mic;
        color = Colors.blue;
        break;
      case ModelType.textSummarization:
        iconData = Icons.summarize;
        color = Colors.green;
        break;
      case ModelType.speakerIdentification:
        iconData = Icons.person;
        color = Colors.orange;
        break;
      case ModelType.languageDetection:
        iconData = Icons.language;
        color = Colors.purple;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(iconData, color: color),
    );
  }

  /// Model metadata (size, languages, etc.)
  Widget _buildModelMetadata(ModelInfo model) {
    return Wrap(
      spacing: 8,
      children: [
        Chip(
          label: Text(_formatFileSize(model.sizeBytes)),
          backgroundColor: Colors.grey.withOpacity(0.1),
          labelStyle: const TextStyle(fontSize: 12),
        ),
        if (model.isQuantized)
          const Chip(
            label: Text('Quantized'),
            backgroundColor: Colors.blue,
            labelStyle: TextStyle(color: Colors.white, fontSize: 12),
          ),
        Chip(
          label: Text('${model.supportedLanguages.length} languages'),
          backgroundColor: Colors.green.withOpacity(0.1),
          labelStyle: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// Model action buttons
  Widget _buildModelActions(ModelInfo model, ModelManager modelManager,
      bool isActuallyDownloaded, bool isDownloading) {
    return Consumer<AiCoordinator>(
      builder: (context, aiCoordinator, child) {
        // Check download state directly to be more reliable
        final downloadState = modelManager.downloadStates[model.id];
        final isCurrentlyDownloading = downloadState?.isDownloading ?? false;

        // Debug logging for download actions
        if (model.id == 'whisper-tiny') {
          debugPrint('=== Whisper Tiny Actions Debug ===');
          debugPrint('  downloadState: ${downloadState?.toString()}');
          debugPrint('  isCurrentlyDownloading: $isCurrentlyDownloading');
          debugPrint('  isActuallyDownloaded: $isActuallyDownloaded');
          debugPrint('================================');
        }

        // Show spinner during entire download process
        if (isCurrentlyDownloading) {
          return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        // Show ACTIVE/Use buttons only when completely downloaded
        if (isActuallyDownloaded) {
          final isActive = _isModelActive(model, aiCoordinator);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (!isActive)
                TextButton(
                  onPressed: () => _switchToModel(model, aiCoordinator),
                  child: const Text('Use'),
                ),
            ],
          );
        }

        return ElevatedButton.icon(
          onPressed: () => _downloadModel(model, modelManager),
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Download'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 36),
          ),
        );
      },
    );
  }

  /// Model detailed information
  Widget _buildModelDetails(ModelInfo model) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('ID', model.id),
          _buildDetailRow('Format', model.modelFormat.toString()),
          _buildDetailRow('Min RAM', '${model.requirements.minRamMB} MB'),
          _buildDetailRow(
              'CPU Optimized', model.requirements.cpuOptimized.toString()),
          _buildDetailRow(
              'GPU Optimized', model.requirements.gpuOptimized.toString()),
          const SizedBox(height: 8),
          const Text('Supported Languages:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: model.supportedLanguages
                .map((lang) => Chip(
                      label: Text(lang.toUpperCase()),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      labelStyle: const TextStyle(fontSize: 12),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Detail row widget
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Active models tab
  Widget _buildActiveModelsTab() {
    return Consumer<AiCoordinator>(
      builder: (context, aiCoordinator, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActiveModelCard(
                'Speech Recognition',
                aiCoordinator.currentSpeechModel,
                Icons.mic,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildActiveModelCard(
                'Text Summarization',
                aiCoordinator.currentSummaryModel,
                Icons.summarize,
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildModeCard(aiCoordinator),
              const SizedBox(height: 16),
              _buildPerformanceCard(aiCoordinator),
            ],
          ),
        );
      },
    );
  }

  /// Active model card
  Widget _buildActiveModelCard(
      String title, String modelId, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(modelId),
        trailing: IconButton(
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => _showModelSwitchDialog(title, modelId),
        ),
      ),
    );
  }

  /// AI Status card showing current models
  Widget _buildModeCard(AiCoordinator aiCoordinator) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: Icon(
            Icons.smart_toy,
            color: Colors.green,
          ),
        ),
        title: const Text('AI Models Active'),
        subtitle: Text(
          'Speech: ${aiCoordinator.currentSpeechModel}\nSummary: ${aiCoordinator.currentSummaryModel}',
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  /// Performance metrics card
  Widget _buildPerformanceCard(AiCoordinator aiCoordinator) {
    final stats = aiCoordinator.getModelStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Available Implementations',
                '${stats['availableImplementations']['speech'].length} speech, ${stats['availableImplementations']['summarization'].length} summary'),
            _buildStatRow(
                'Performance History', '${stats['performanceHistory']} events'),
            if (stats['lastModelSwitch'] != null)
              _buildStatRow(
                  'Last Switch', _formatDateTime(stats['lastModelSwitch'])),
          ],
        ),
      ),
    );
  }

  /// Downloads tab
  Widget _buildDownloadsTab() {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final downloadStates = modelManager.downloadStates;

        if (downloadStates.isEmpty) {
          return const Center(
            child: Text('No downloads in progress'),
          );
        }

        return ListView.builder(
          itemCount: downloadStates.length,
          itemBuilder: (context, index) {
            final entry = downloadStates.entries.elementAt(index);
            final modelId = entry.key;
            final state = entry.value;
            final model = modelManager.availableModels[modelId];

            if (model == null) return const SizedBox.shrink();

            return _buildDownloadCard(model, state);
          },
        );
      },
    );
  }

  /// Download progress card
  Widget _buildDownloadCard(ModelInfo model, ModelDownloadState state) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildModelIcon(model.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    model.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (state.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green),
                if (state.error != null)
                  const Icon(Icons.error, color: Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: Colors.grey.withOpacity(0.2),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(state.progress * 100).toStringAsFixed(1)}%'),
                Text(_formatFileSize(model.sizeBytes)),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${state.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Analytics tab
  Widget _buildAnalyticsTab() {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStorageAnalytics(modelManager),
              const SizedBox(height: 16),
              _buildModelAnalytics(modelManager),
            ],
          ),
        );
      },
    );
  }

  /// Storage analytics
  Widget _buildStorageAnalytics(ModelManager modelManager) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    LinearProgressIndicator(
                      value: used / total,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Used: ${_formatFileSize(used)}'),
                        Text('${percentage.toStringAsFixed(1)}%'),
                        Text('Total: ${_formatFileSize(total)}'),
                      ],
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

  /// Model analytics
  Widget _buildModelAnalytics(ModelManager modelManager) {
    final stats = modelManager.getStorageStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Model Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total Available', '${stats['totalModels']}'),
            _buildStatRow('Downloaded', '${stats['downloadedModels']}'),
            _buildStatRow('Loaded in Memory', '${stats['loadedInstances']}'),
          ],
        ),
      ),
    );
  }

  /// Statistic row
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Helper methods

  bool _isModelActive(ModelInfo model, AiCoordinator aiCoordinator) {
    switch (model.type) {
      case ModelType.speechRecognition:
        return aiCoordinator.currentSpeechModel == model.id;
      case ModelType.textSummarization:
        return aiCoordinator.currentSummaryModel == model.id;
      default:
        return false;
    }
  }

  Future<void> _downloadModel(
      ModelInfo model, ModelManager modelManager) async {
    final success = await modelManager.downloadModel(model.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Download started for ${model.name}'
                : 'Failed to start download: ${modelManager.lastError}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _switchToModel(
      ModelInfo model, AiCoordinator aiCoordinator) async {
    bool success = false;

    switch (model.type) {
      case ModelType.speechRecognition:
        success = await aiCoordinator.switchSpeechModel(model.id);
        break;
      case ModelType.textSummarization:
        success = await aiCoordinator.switchSummarizationModel(model.id);
        break;
      default:
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Switched to ${model.name}'
                : 'Failed to switch: ${aiCoordinator.lastError}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showModelSwitchDialog(String type, String currentModel) {
    // TODO: Implement model switch dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Model switching for $type coming soon'),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Never';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }
}
