import 'package:flutter/material.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

class RouteControlPanel extends StatelessWidget {
  final bool isTracking;
  final bool isPaused;
  final VoidCallback? onStartTracking;
  final VoidCallback? onStopTracking;
  final VoidCallback? onPauseTracking;
  final VoidCallback? onResumeTracking;

  const RouteControlPanel({super.key, required this.isTracking, required this.isPaused, this.onStartTracking, this.onStopTracking, this.onPauseTracking, this.onResumeTracking});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
            ElevatedButton.icon(
              onPressed: onResumeTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text(AppStrings.resume),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.white),
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
