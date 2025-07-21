import 'package:flutter/material.dart';
import '../../core/audio/audio_visualizer.dart';

/// Widget wrapper for the audio visualizer
class AudioVisualizerWidget extends StatelessWidget {
  final AudioVisualizer? visualizer;
  final double height;

  const AudioVisualizerWidget({
    super.key,
    required this.visualizer,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (visualizer == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Audio Visualizer',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: StreamBuilder<AudioVisualizerData>(
        stream: visualizer!.dataStream,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text(
                'No audio data',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return CustomPaint(
            painter: AudioVisualizerPainter(data),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

/// Custom painter for audio visualizer
class AudioVisualizerPainter extends CustomPainter {
  final AudioVisualizerData data;

  AudioVisualizerPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final barWidth = size.width / data.spectrum.length;

    for (int i = 0; i < data.spectrum.length; i++) {
      final barHeight = data.spectrum[i] * size.height;
      final x = i * barWidth;
      final y = size.height - barHeight;

      canvas.drawRect(
        Rect.fromLTWH(x, y, barWidth - 1, barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
