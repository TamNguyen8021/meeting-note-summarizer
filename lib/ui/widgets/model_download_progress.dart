import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ai/enhanced_model_manager.dart';

/// Widget that displays download progress for AI models
class ModelDownloadProgress extends StatelessWidget {
  const ModelDownloadProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        final downloadStates = modelManager.downloadStates;

        // Debug logging
        debugPrint(
            'ModelDownloadProgress: Found ${downloadStates.length} download states');
        for (final entry in downloadStates.entries) {
          debugPrint(
              '  ${entry.key}: isDownloading=${entry.value.isDownloading}, progress=${entry.value.progress}, completed=${entry.value.isCompleted}');
        }

        final activeDownloads = downloadStates.entries
            .where((entry) =>
                entry.value.isDownloading ||
                (entry.value.progress > 0 && !entry.value.isCompleted))
            .toList();

        debugPrint(
            'ModelDownloadProgress: Found ${activeDownloads.length} active downloads');
        for (final entry in activeDownloads) {
          debugPrint('  Active: ${entry.key} - ${entry.value.progress}%');
        }

        if (activeDownloads.isEmpty) {
          // Don't show anything if no active downloads
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.download,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Downloading AI Models',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const Spacer(),
                  if (activeDownloads.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${activeDownloads.length} models',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ...activeDownloads.map((entry) => _buildModelProgress(
                    context,
                    entry.key,
                    entry.value,
                    modelManager,
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelProgress(
    BuildContext context,
    String modelId,
    ModelDownloadState downloadState,
    ModelManager modelManager,
  ) {
    final model = modelManager.availableModels[modelId];
    final modelName = model?.name ?? modelId;
    final progress = downloadState.progress;
    final isError = downloadState.error != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  modelName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
              Text(
                isError
                    ? 'Failed'
                    : downloadState.isCompleted
                        ? 'Complete'
                        : '${(progress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isError
                          ? Theme.of(context).colorScheme.error
                          : downloadState.isCompleted
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isError) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: downloadState.isCompleted ? 1.0 : progress,
                backgroundColor:
                    Theme.of(context).colorScheme.outline.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  downloadState.isCompleted
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary,
                ),
                minHeight: 8,
              ),
            ),
            if (model != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _formatBytes(model.sizeBytes),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                  ),
                  const Spacer(),
                  if (downloadState.isDownloading && progress > 0)
                    Text(
                      'Downloaded: ${_formatBytes((model.sizeBytes * progress).round())}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                ],
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      downloadState.error ?? 'Download failed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
