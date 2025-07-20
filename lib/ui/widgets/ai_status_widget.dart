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
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStatusColor(aiCoordinator).withOpacity(0.3),
                width: 1,
              ),
              gradient: LinearGradient(
                colors: [
                  _getStatusColor(aiCoordinator).withOpacity(0.05),
                  _getStatusColor(aiCoordinator).withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(aiCoordinator),
                if (widget.showDetailedStats) ...[
                  const SizedBox(height: 12),
                  _buildDetailedStats(aiCoordinator, modelManager),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(AiCoordinator aiCoordinator) {
    return Row(
      children: [
        // AI Mode indicator
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            tooltip: 'Switch AI Mode',
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
    if (aiCoordinator.useMockImplementations) {
      return Colors.orange;
    }
    return Colors.green;
  }

  IconData _getStatusIcon(AiCoordinator aiCoordinator) {
    if (aiCoordinator.useMockImplementations) {
      return Icons.code;
    }
    return Icons.smart_toy;
  }

  String _getStatusText(AiCoordinator aiCoordinator) {
    if (aiCoordinator.useMockImplementations) {
      return 'MOCK AI';
    }
    return 'REAL AI';
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
      case 'mock-speech':
        return 'Mock Speech';
      case 'mock-summary':
        return 'Mock Summary';
      default:
        return modelId;
    }
  }
}

/// Quick switch bottom sheet for changing AI modes and models
class _QuickSwitchSheet extends StatelessWidget {
  final AiCoordinator aiCoordinator;

  const _QuickSwitchSheet({required this.aiCoordinator});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick AI Switch',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // AI Mode toggle
            _buildModeToggle(context),
            const SizedBox(height: 16),

            // Quick model presets
            Text(
              'Quick Presets',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 12),
            _buildPresetButtons(context),

            const SizedBox(height: 16),

            // Advanced button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navigate to model management screen
                },
                icon: const Icon(Icons.settings),
                label: const Text('Advanced Model Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _switchToMock(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: aiCoordinator.useMockImplementations
                      ? Colors.orange
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.code,
                      size: 16,
                      color: aiCoordinator.useMockImplementations
                          ? Colors.white
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mock AI',
                      style: TextStyle(
                        color: aiCoordinator.useMockImplementations
                            ? Colors.white
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _switchToReal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !aiCoordinator.useMockImplementations
                      ? Colors.green
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.smart_toy,
                      size: 16,
                      color: !aiCoordinator.useMockImplementations
                          ? Colors.white
                          : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Real AI',
                      style: TextStyle(
                        color: !aiCoordinator.useMockImplementations
                            ? Colors.white
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtons(BuildContext context) {
    return Column(
      children: [
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
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

  Future<void> _switchToMock(BuildContext context) async {
    if (!aiCoordinator.useMockImplementations) {
      await aiCoordinator.switchToMockImplementations();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to Mock AI mode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _switchToReal(BuildContext context) async {
    if (aiCoordinator.useMockImplementations) {
      final success = await aiCoordinator.switchToRealImplementations();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Switched to Real AI mode'
                  : 'Failed to switch: ${aiCoordinator.lastError}',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyPreset(
      BuildContext context, String speechModel, String summaryModel) async {
    Navigator.pop(context);

    // Switch to real AI first if needed
    if (aiCoordinator.useMockImplementations) {
      await aiCoordinator.switchToRealImplementations();
    }

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
}
