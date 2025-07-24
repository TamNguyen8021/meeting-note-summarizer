import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ai/ai_coordinator.dart';
import '../../core/ai/enhanced_model_manager.dart';

/// Real-time AI status widget showing active models, performance, and switching capabilities
class AiStatusWidget extends StatefulWidget {
  final bool showDetailedStats;
  final bool allowModelSwitching;
  final VoidCallback? onTap;

  const AiStatusWidget({
    super.key,
    this.showDetailedStats = false,
    this.allowModelSwitching = true,
    this.onTap,
  });

  @override
  State<AiStatusWidget> createState() => _AiStatusWidgetState();
}

class _AiStatusWidgetState extends State<AiStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AiCoordinator, ModelManager>(
      builder: (context, aiCoordinator, modelManager, child) {
        if (!aiCoordinator.isInitialized) {
          return _buildLoadingIndicator();
        }

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: widget.showDetailedStats
                ? _buildDetailedStats(aiCoordinator, modelManager)
                : _buildCompactStatus(aiCoordinator),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 6),
          Text(
            'Loading AI...',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatus(AiCoordinator aiCoordinator) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status indicator with animation
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(aiCoordinator)
                    .withOpacity(_glowAnimation.value * 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(aiCoordinator)
                      .withOpacity(_glowAnimation.value),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(aiCoordinator),
                    size: 12,
                    color: _getStatusColor(aiCoordinator),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(aiCoordinator),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(aiCoordinator),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const Spacer(),

        // Quick switch button
        if (widget.allowModelSwitching)
          IconButton(
            onPressed: () => _showQuickSwitchMenu(context, aiCoordinator),
            icon: Icon(
              Icons.swap_horiz,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
            tooltip: 'Switch AI Models',
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildDetailedStats(
      AiCoordinator aiCoordinator, ModelManager modelManager) {
    final stats = aiCoordinator.getModelStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModelRow(
          'Speech',
          aiCoordinator.currentSpeechModel,
          Icons.mic,
          Colors.blue,
        ),
        const SizedBox(height: 6),
        _buildModelRow(
          'Summary',
          aiCoordinator.currentSummaryModel,
          Icons.summarize,
          Colors.green,
        ),
        const SizedBox(height: 8),
        _buildPerformanceIndicators(stats),
      ],
    );
  }

  Widget _buildModelRow(
      String label, String modelId, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          '$label:',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _formatModelName(modelId),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceIndicators(Map<String, dynamic> stats) {
    return Row(
      children: [
        _buildMetricChip(
          'Models',
          '${stats['availableImplementations']['speech'].length + stats['availableImplementations']['summarization'].length}',
          Icons.storage,
        ),
        const SizedBox(width: 8),
        _buildMetricChip(
          'History',
          '${stats['performanceHistory']}',
          Icons.history,
        ),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey[600]),
          const SizedBox(width: 3),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickSwitchMenu(BuildContext context, AiCoordinator aiCoordinator) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _QuickSwitchSheet(aiCoordinator: aiCoordinator),
    );
  }

  // Helper methods

  Color _getStatusColor(AiCoordinator aiCoordinator) {
    if (aiCoordinator.isModelSwitching) {
      return Colors.orange;
    }
    return Colors.green;
  }

  IconData _getStatusIcon(AiCoordinator aiCoordinator) {
    if (aiCoordinator.isModelSwitching) {
      return Icons.sync;
    }
    return Icons.smart_toy;
  }

  String _getStatusText(AiCoordinator aiCoordinator) {
    if (aiCoordinator.isModelSwitching) {
      return 'SWITCHING';
    }
    return 'AI READY';
  }

  String _formatModelName(String modelId) {
    switch (modelId) {
      case 'whisper-tiny':
        return 'Whisper Tiny';
      case 'whisper-base':
        return 'Whisper Base';
      case 'whisper-small':
        return 'Whisper Small';
      case 'llama-3.2-1b-q4':
        return 'Llama 3.2 1B';
      case 'llama-3.2-3b-q4':
        return 'Llama 3.2 3B';
      case 'tinyllama-q4':
        return 'TinyLlama';
      case 'phi-3-mini-q4':
        return 'Phi-3 Mini';
      default:
        return modelId;
    }
  }
}

/// Quick switch bottom sheet for changing AI models
class _QuickSwitchSheet extends StatefulWidget {
  final AiCoordinator aiCoordinator;

  const _QuickSwitchSheet({required this.aiCoordinator});

  @override
  State<_QuickSwitchSheet> createState() => _QuickSwitchSheetState();
}

class _QuickSwitchSheetState extends State<_QuickSwitchSheet> {
  AiCoordinator get aiCoordinator => widget.aiCoordinator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'AI Model Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCurrentModels(),
          const SizedBox(height: 16),
          _buildPresetButtons(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCurrentModels() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Models',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.mic, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                  'Speech: ${_formatModelName(aiCoordinator.currentSpeechModel)}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.summarize, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                  'Summary: ${_formatModelName(aiCoordinator.currentSummaryModel)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Presets',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        _buildPresetButton(
          context,
          'Fast & Light',
          'Whisper Tiny + TinyLlama',
          Icons.speed,
          Colors.blue,
          () => _applyPreset(context, 'whisper-tiny', 'tinyllama-q4'),
        ),
        const SizedBox(height: 8),
        _buildPresetButton(
          context,
          'Balanced',
          'Whisper Base + Llama 3.2 1B',
          Icons.balance,
          Colors.green,
          () => _applyPreset(context, 'whisper-base', 'llama-3.2-1b-q4'),
        ),
        const SizedBox(height: 8),
        _buildPresetButton(
          context,
          'High Quality',
          'Whisper Small + Llama 3.2 3B',
          Icons.high_quality,
          Colors.purple,
          () => _applyPreset(context, 'whisper-small', 'llama-3.2-3b-q4'),
        ),
      ],
    );
  }

  Widget _buildPresetButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _applyPreset(
      BuildContext context, String speechModel, String summaryModel) async {
    Navigator.pop(context);

    // Switch models
    final speechSuccess = await aiCoordinator.switchSpeechModel(speechModel);
    final summarySuccess =
        await aiCoordinator.switchSummarizationModel(summaryModel);

    if (context.mounted) {
      final message = (speechSuccess && summarySuccess)
          ? 'Applied preset successfully'
          : 'Failed to apply some models: ${aiCoordinator.lastError}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              (speechSuccess && summarySuccess) ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  String _formatModelName(String modelId) {
    switch (modelId) {
      case 'whisper-tiny':
        return 'Whisper Tiny';
      case 'whisper-base':
        return 'Whisper Base';
      case 'whisper-small':
        return 'Whisper Small';
      case 'llama-3.2-1b-q4':
        return 'Llama 3.2 1B';
      case 'llama-3.2-3b-q4':
        return 'Llama 3.2 3B';
      case 'tinyllama-q4':
        return 'TinyLlama';
      case 'phi-3-mini-q4':
        return 'Phi-3 Mini';
      default:
        return modelId;
    }
  }
}
