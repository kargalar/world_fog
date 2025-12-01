import 'package:flutter/material.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

class RouteControlPanel extends StatelessWidget {
  final bool isTracking;
  final bool isPaused;
  final Duration? currentBreakDuration; // Geçerli mola süresi
  final VoidCallback? onStartTracking;
  final VoidCallback? onStopTracking;
  final VoidCallback? onPauseTracking;
  final VoidCallback? onResumeTracking;

  const RouteControlPanel({super.key, required this.isTracking, required this.isPaused, this.currentBreakDuration, this.onStartTracking, this.onStopTracking, this.onPauseTracking, this.onResumeTracking});

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isTracking) ...[
          ElevatedButton.icon(
            onPressed: onStartTracking,
            icon: const Icon(Icons.play_arrow),
            label: const Text(AppStrings.startTracking),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.white),
          ),
        ] else ...[
          if (!isPaused) ...[
            ElevatedButton.icon(
              onPressed: onPauseTracking,
              icon: const Icon(Icons.pause),
              label: const Text(AppStrings.pause),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: AppColors.white),
            ),
            const SizedBox(width: 8),
          ] else ...[
            // Pause halinde - geçerli mola süresi ile birlikte resume butonu
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentBreakDuration != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(color: AppColors.orange.withAlpha(50), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pause_circle, color: AppColors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(currentBreakDuration!),
                          style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: onResumeTracking,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(AppStrings.resume),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.white),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton.icon(
            onPressed: onStopTracking,
            icon: const Icon(Icons.stop),
            label: const Text(AppStrings.stop),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
          ),
        ],
      ],
    );
  }
}
