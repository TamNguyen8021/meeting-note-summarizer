import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Real-time audio level visualizer with frequency analysis
/// Shows audio input levels, quality metrics, and adaptive model switching indicators
class AudioVisualizer extends StatefulWidget {
  final double level;
  final double quality;
  final bool isRecording;
  final bool isProcessing;
  final String currentModel;
  final Color? primaryColor;
  final double? height;
  final double? width;

  const AudioVisualizer({
    super.key,
    this.level = 0.0,
    this.quality = 0.0,
    this.isRecording = false,
    this.isProcessing = false,
    this.currentModel = 'None',
    this.primaryColor,
    this.height = 80,
    this.width,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  // Simulated frequency data for visualization
  final List<double> _frequencyBands = List.generate(32, (index) => 0.0);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));

    _waveController.repeat();
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    // Update frequency bands based on audio level
    if (widget.isRecording && widget.level > 0) {
      _updateFrequencyBands();
    }
  }

  void _updateFrequencyBands() {
    final random = math.Random();
    for (int i = 0; i < _frequencyBands.length; i++) {
      // Simulate frequency response based on audio level
      final baseLevel = widget.level * (1.0 - i / _frequencyBands.length);
      _frequencyBands[i] =
          math.max(0.0, baseLevel + (random.nextDouble() - 0.5) * 0.3);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = (widget.height ?? 80) < 80;

    return Container(
      height: widget.height,
      width: widget.width,
      padding: EdgeInsets.all(isCompact ? 6 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isRecording
              ? (widget.primaryColor ?? Theme.of(context).primaryColor)
              : Colors.grey.withOpacity(0.3),
          width: widget.isRecording ? 2 : 1,
        ),
        gradient: widget.isRecording
            ? LinearGradient(
                colors: [
                  (widget.primaryColor ?? Theme.of(context).primaryColor)
                      .withOpacity(0.1),
                  (widget.primaryColor ?? Theme.of(context).primaryColor)
                      .withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        children: [
          // Status row (only show if not compact or if recording)
          if (!isCompact || widget.isRecording) ...[
            _buildStatusRow(isCompact: isCompact),
            SizedBox(height: isCompact ? 4 : 8),
          ],
          // Main visualizer
          Expanded(
            child: widget.isRecording
                ? _buildActiveVisualizer()
                : _buildInactiveVisualizer(),
          ),
        ],
      ),
    );
  }

  /// Status row with quality and model information
  Widget _buildStatusRow({bool isCompact = false}) {
    return Row(
      children: [
        // Recording indicator
        Container(
          width: isCompact ? 6 : 8,
          height: isCompact ? 6 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isRecording ? Colors.red : Colors.grey,
          ),
          child: widget.isRecording
              ? AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
        SizedBox(width: isCompact ? 4 : 8),

        // Status text
        if (!isCompact)
          Text(
            widget.isRecording ? 'Recording' : 'Ready',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: widget.isRecording
                      ? (widget.primaryColor ?? Theme.of(context).primaryColor)
                      : Colors.grey,
                ),
          ),

        const Spacer(),

        // Quality indicator
        if (widget.isRecording && !isCompact) ...[
          Icon(
            _getQualityIcon(),
            size: 12,
            color: _getQualityColor(),
          ),
          const SizedBox(width: 4),
          Text(
            '${(widget.quality * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: _getQualityColor(),
                ),
          ),
        ],

        // Processing indicator
        if (widget.isProcessing) ...[
          SizedBox(width: isCompact ? 4 : 8),
          SizedBox(
            width: isCompact ? 8 : 12,
            height: isCompact ? 8 : 12,
            child: CircularProgressIndicator(
              strokeWidth: isCompact ? 1.5 : 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.primaryColor ?? Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Active visualizer with frequency bars and waveform
  Widget _buildActiveVisualizer() {
    return Row(
      children: [
        // Level meter
        _buildLevelMeter(),
        const SizedBox(width: 12),

        // Frequency bars
        Expanded(
          child: _buildFrequencyBars(),
        ),
        const SizedBox(width: 12),

        // Waveform
        _buildWaveform(),
      ],
    );
  }

  /// Level meter (vertical bar)
  Widget _buildLevelMeter() {
    return Container(
      width: 6,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.grey.withOpacity(0.2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.bottomCenter,
        heightFactor: math.max(0.1, widget.level),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.green,
                Colors.yellow,
                Colors.red,
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// Frequency bars visualization
  Widget _buildFrequencyBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _frequencyBands.asMap().entries.map((entry) {
        final value = entry.value;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 3,
          height: math.max(2, value * 30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1.5),
            color: (widget.primaryColor ?? Theme.of(context).primaryColor)
                .withOpacity(0.3 + value * 0.7),
          ),
        );
      }).toList(),
    );
  }

  /// Animated waveform
  Widget _buildWaveform() {
    return SizedBox(
      width: 40,
      height: double.infinity,
      child: AnimatedBuilder(
        animation: _waveAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: WaveformPainter(
              amplitude: widget.level * 20,
              phase: _waveAnimation.value,
              color: widget.primaryColor ?? Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }

  /// Inactive visualizer (static state)
  Widget _buildInactiveVisualizer() {
    // Check if we have enough space for full content
    final hasEnoughSpace = (widget.height ?? 80) >= 40;

    return Center(
      child: hasEnoughSpace
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_off_outlined,
                  size: 20,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.withOpacity(0.7),
                        fontSize: 9,
                      ),
                ),
              ],
            )
          : Icon(
              Icons.mic_off_outlined,
              size: (widget.height ?? 80) * 0.4,
              color: Colors.grey.withOpacity(0.5),
            ),
    );
  }

  // Helper methods

  IconData _getQualityIcon() {
    if (widget.quality >= 0.8) return Icons.signal_cellular_4_bar;
    if (widget.quality >= 0.6) return Icons.signal_cellular_alt_2_bar;
    if (widget.quality >= 0.4) return Icons.signal_cellular_alt_1_bar;
    if (widget.quality >= 0.2)
      return Icons.signal_cellular_connected_no_internet_0_bar;
    return Icons.signal_cellular_0_bar;
  }

  Color _getQualityColor() {
    if (widget.quality >= 0.7) return Colors.green;
    if (widget.quality >= 0.4) return Colors.orange;
    return Colors.red;
  }
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final double amplitude;
  final double phase;
  final Color color;

  WaveformPainter({
    required this.amplitude,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerY = size.height / 2;

    for (double x = 0; x < size.width; x += 1) {
      final normalizedX = x / size.width;
      final y = centerY +
          math.sin((normalizedX * 4 * math.pi) + phase) * amplitude * 0.5;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color;
  }
}

/// Compact audio level indicator for smaller spaces
class CompactAudioIndicator extends StatelessWidget {
  final double level;
  final bool isActive;
  final Color? color;

  const CompactAudioIndicator({
    super.key,
    this.level = 0.0,
    this.isActive = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final threshold = (index + 1) * 0.25;
        final isLit = isActive && level >= threshold;

        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: 3,
          height: 8 + (index * 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1.5),
            color: isLit
                ? (color ?? Theme.of(context).primaryColor)
                : Colors.grey.withOpacity(0.3),
          ),
        );
      }),
    );
  }
}
