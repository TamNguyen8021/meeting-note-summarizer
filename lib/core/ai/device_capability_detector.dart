import 'dart:io';
import 'package:flutter/foundation.dart';

/// Device capability information for AI model selection
class DeviceCapabilities {
  /// Available RAM in GB
  final double availableRamGB;

  /// Number of CPU cores
  final int cpuCores;

  /// Has GPU acceleration support
  final bool hasGpuAcceleration;

  /// Platform type
  final String platform;

  /// Device performance tier (low, medium, high)
  final DevicePerformanceTier performanceTier;

  /// Recommended speech model based on capabilities
  final String recommendedSpeechModel;

  /// Recommended summarization model based on capabilities
  final String recommendedSummaryModel;

  const DeviceCapabilities({
    required this.availableRamGB,
    required this.cpuCores,
    required this.hasGpuAcceleration,
    required this.platform,
    required this.performanceTier,
    required this.recommendedSpeechModel,
    required this.recommendedSummaryModel,
  });
}

/// Device performance tiers for model selection
enum DevicePerformanceTier {
  low, // < 4GB RAM, < 4 cores
  medium, // 4-8GB RAM, 4-8 cores
  high, // > 8GB RAM, > 8 cores
}

/// Detects device capabilities for optimal AI model selection
class DeviceCapabilityDetector {
  static DeviceCapabilities? _cachedCapabilities;
  static bool _isDetecting = false;

  /// Get device capabilities (cached after first call)
  static Future<DeviceCapabilities> getCapabilities() async {
    if (_cachedCapabilities != null) {
      return _cachedCapabilities!;
    }

    // Prevent multiple simultaneous detection attempts
    if (_isDetecting) {
      // Wait for the current detection to complete
      while (_isDetecting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedCapabilities ?? await _detectCapabilities();
    }

    _isDetecting = true;
    try {
      _cachedCapabilities = await _detectCapabilities();
      return _cachedCapabilities!;
    } finally {
      _isDetecting = false;
    }
  }

  /// Force refresh of device capabilities
  static Future<DeviceCapabilities> refreshCapabilities() async {
    _cachedCapabilities = await _detectCapabilities();
    return _cachedCapabilities!;
  }

  /// Internal method to detect device capabilities
  static Future<DeviceCapabilities> _detectCapabilities() async {
    try {
      // Get basic platform information
      final platform = Platform.operatingSystem;
      final cpuCores = await _getCpuCores();
      final availableRam = await _getAvailableRam();
      final hasGpu = await _detectGpuAcceleration();

      // Determine performance tier
      final performanceTier = _determinePerformanceTier(availableRam, cpuCores);

      // Recommend models based on capabilities
      final speechModel = _recommendSpeechModel(performanceTier, availableRam);
      final summaryModel =
          _recommendSummaryModel(performanceTier, availableRam);

      return DeviceCapabilities(
        availableRamGB: availableRam,
        cpuCores: cpuCores,
        hasGpuAcceleration: hasGpu,
        platform: platform,
        performanceTier: performanceTier,
        recommendedSpeechModel: speechModel,
        recommendedSummaryModel: summaryModel,
      );
    } catch (e) {
      debugPrint('Error detecting device capabilities: $e');
      // Return conservative defaults on error
      return const DeviceCapabilities(
        availableRamGB: 4.0,
        cpuCores: 4,
        hasGpuAcceleration: false,
        platform: 'unknown',
        performanceTier: DevicePerformanceTier.low,
        recommendedSpeechModel: 'whisper-tiny',
        recommendedSummaryModel: 'tinyllama-q4',
      );
    }
  }

  /// Get CPU core count
  static Future<int> _getCpuCores() async {
    try {
      // Use isolate count as approximation for CPU cores
      return Platform.numberOfProcessors;
    } catch (e) {
      debugPrint('Could not detect CPU cores: $e');
      return 4; // Conservative default
    }
  }

  /// Estimate available RAM in GB
  static Future<double> _getAvailableRam() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile devices typically have less RAM
        return await _estimateMobileRam();
      } else {
        // Desktop/laptop - use system info if available
        return await _estimateDesktopRam();
      }
    } catch (e) {
      debugPrint('Could not detect RAM: $e');
      return 4.0; // Conservative default
    }
  }

  /// Estimate mobile device RAM
  static Future<double> _estimateMobileRam() async {
    // This is a rough estimation - in production you'd use platform channels
    // to get actual memory info from native code
    if (Platform.isIOS) {
      // iOS devices generally have good memory management
      return 6.0; // Assume modern iOS device
    } else {
      // Android devices vary widely
      return 4.0; // Conservative estimate
    }
  }

  /// Estimate desktop RAM
  static Future<double> _estimateDesktopRam() async {
    try {
      if (Platform.isWindows) {
        // Use Windows system info
        final result = await Process.run(
            'wmic', ['computersystem', 'get', 'TotalPhysicalMemory', '/value']);

        final output = result.stdout.toString();
        final match = RegExp(r'TotalPhysicalMemory=(\d+)').firstMatch(output);
        if (match != null) {
          final bytes = int.parse(match.group(1)!);
          return bytes / (1024 * 1024 * 1024); // Convert to GB
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        // Use /proc/meminfo on Linux or system_profiler on macOS
        final command = Platform.isLinux ? 'cat' : 'system_profiler';
        final args =
            Platform.isLinux ? ['/proc/meminfo'] : ['SPHardwareDataType'];

        final result = await Process.run(command, args);
        final output = result.stdout.toString();

        if (Platform.isLinux) {
          final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(output);
          if (match != null) {
            final kb = int.parse(match.group(1)!);
            return kb / (1024 * 1024); // Convert to GB
          }
        } else {
          // Parse macOS system_profiler output
          final match = RegExp(r'Memory:\s+(\d+)\s+GB').firstMatch(output);
          if (match != null) {
            return double.parse(match.group(1)!);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting system RAM info: $e');
    }

    return 8.0; // Reasonable default for desktop
  }

  /// Detect GPU acceleration support
  static Future<bool> _detectGpuAcceleration() async {
    try {
      // This would require platform-specific detection
      // For now, assume false on mobile, possible on desktop
      if (Platform.isAndroid || Platform.isIOS) {
        return false; // Mobile GPUs typically not suitable for LLM inference
      } else {
        // Could check for NVIDIA/AMD/Intel GPU presence
        return false; // Conservative default - enable when FFI supports GPU
      }
    } catch (e) {
      return false;
    }
  }

  /// Determine performance tier based on hardware
  static DevicePerformanceTier _determinePerformanceTier(
      double ramGB, int cores) {
    if (ramGB >= 16 && cores >= 8) {
      return DevicePerformanceTier.high;
    } else if (ramGB >= 8 && cores >= 4) {
      return DevicePerformanceTier.medium;
    } else {
      return DevicePerformanceTier.low;
    }
  }

  /// Recommend speech recognition model based on capabilities
  static String _recommendSpeechModel(
      DevicePerformanceTier tier, double ramGB) {
    switch (tier) {
      case DevicePerformanceTier.high:
        if (ramGB >= 16) {
          return 'whisper-small'; // Best accuracy for high-end devices
        } else {
          return 'whisper-base';
        }
      case DevicePerformanceTier.medium:
        return 'whisper-base'; // Balanced accuracy/performance
      case DevicePerformanceTier.low:
        return 'whisper-tiny'; // Fastest inference for low-end devices
    }
  }

  /// Recommend summarization model based on capabilities
  static String _recommendSummaryModel(
      DevicePerformanceTier tier, double ramGB) {
    switch (tier) {
      case DevicePerformanceTier.high:
        if (ramGB >= 16) {
          return 'llama-3.2-3b-q4'; // Best quality for high-end devices
        } else {
          return 'llama-3.2-1b-q4';
        }
      case DevicePerformanceTier.medium:
        return 'llama-3.2-1b-q4'; // Good quality with reasonable memory usage
      case DevicePerformanceTier.low:
        return 'tinyllama-q4'; // Minimal memory footprint
    }
  }

  /// Get model recommendations for current device
  static Future<Map<String, String>> getModelRecommendations() async {
    final capabilities = await getCapabilities();
    return {
      'speech': capabilities.recommendedSpeechModel,
      'summarization': capabilities.recommendedSummaryModel,
    };
  }

  /// Check if device can handle a specific model
  static Future<bool> canHandleModel(String modelId, double modelSizeGB) async {
    final capabilities = await getCapabilities();

    // Conservative check: require 2x model size in available RAM
    final requiredRam = modelSizeGB * 2;

    if (capabilities.availableRamGB < requiredRam) {
      return false;
    }

    // Additional checks based on model type and device capabilities
    if (modelId.contains('large') &&
        capabilities.performanceTier == DevicePerformanceTier.low) {
      return false;
    }

    return true;
  }

  /// Get device capability summary for debugging
  static Future<Map<String, dynamic>> getCapabilitySummary() async {
    final capabilities = await getCapabilities();
    return {
      'ram_gb': capabilities.availableRamGB,
      'cpu_cores': capabilities.cpuCores,
      'has_gpu': capabilities.hasGpuAcceleration,
      'platform': capabilities.platform,
      'performance_tier': capabilities.performanceTier.toString(),
      'recommended_speech': capabilities.recommendedSpeechModel,
      'recommended_summary': capabilities.recommendedSummaryModel,
    };
  }
}
