import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ai/enhanced_model_manager.dart';

/// Debug widget to test ModelManager connectivity and download states
class ModelManagerDebugWidget extends StatelessWidget {
  const ModelManagerDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final downloadStates = modelManager.downloadStates;
        final availableModels = modelManager.availableModels;

        // Add debug timestamp to see when widget rebuilds
        debugPrint('ModelManagerDebugWidget rebuilding at ${DateTime.now()}');

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ModelManager Debug Info (${DateTime.now().millisecondsSinceEpoch})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text('Available models: ${availableModels.length}'),
              Text('Download states: ${downloadStates.length}'),
              Text('Is downloading: ${modelManager.isDownloading}'),
              const SizedBox(height: 8),
              if (downloadStates.isNotEmpty) ...[
                Text('Download States:',
                    style: Theme.of(context).textTheme.titleSmall),
                ...downloadStates.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        '${entry.key}: ${entry.value.isDownloading ? "downloading" : "idle"} '
                        '(${(entry.value.progress * 100).toStringAsFixed(1)}%) '
                        '${entry.value.isCompleted ? "COMPLETED" : ""}',
                        style: TextStyle(
                          color: entry.value.isDownloading
                              ? Colors.green
                              : Colors.black,
                          fontWeight: entry.value.isDownloading
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    )),
              ],
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _testDownload(context, modelManager),
                child: const Text('Test Download tinyllama-q4'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _testDownload(BuildContext context, ModelManager modelManager) async {
    debugPrint('Testing download of tinyllama-q4...');
    try {
      final success = await modelManager.downloadModel('tinyllama-q4');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Download successful!'
              : 'Download failed: ${modelManager.lastError}'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
