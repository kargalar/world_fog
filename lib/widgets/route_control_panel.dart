import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F1F1F) : Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isTracking) ...[
            ElevatedButton.icon(
              onPressed: onStartTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text(AppStrings.startTracking),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ] else ...[
            if (!isPaused) ...[
              ElevatedButton.icon(
                onPressed: onPauseTracking,
                icon: const Icon(Icons.pause),
                label: const Text(AppStrings.pause),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
            ] else ...[
              ElevatedButton.icon(
                onPressed: onResumeTracking,
                icon: const Icon(Icons.play_arrow),
                label: const Text(AppStrings.resume),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton.icon(
              onPressed: onStopTracking,
              icon: const Icon(Icons.stop),
              label: const Text(AppStrings.stop),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
