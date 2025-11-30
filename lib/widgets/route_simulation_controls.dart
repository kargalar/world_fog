import 'package:flutter/material.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

class RouteSimulationControls extends StatelessWidget {
  final bool isSimulating;
  final bool isPaused;
  final double sliderValue;
  final int currentPointIndex;
  final int totalPoints;
  final DateTime? currentSimulationTime;
  final VoidCallback? onStartSimulation;
  final VoidCallback? onPauseSimulation;
  final VoidCallback? onResumeSimulation;
  final VoidCallback? onStopSimulation;
  final Function(double)? onSliderChanged;
  final Function(double)? onSliderChangeStart;
  final Function(double)? onSliderChangeEnd;

  const RouteSimulationControls({
    super.key,
    required this.isSimulating,
    required this.isPaused,
    required this.sliderValue,
    required this.currentPointIndex,
    required this.totalPoints,
    this.currentSimulationTime,
    this.onStartSimulation,
    this.onPauseSimulation,
    this.onResumeSimulation,
    this.onStopSimulation,
    this.onSliderChanged,
    this.onSliderChangeStart,
    this.onSliderChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F1F1F) : AppColors.greyShade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time and progress info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${AppStrings.progress} ${currentPointIndex + 1} / $totalPoints', style: const TextStyle(fontSize: 12, color: AppColors.grey)),
              if (currentSimulationTime != null)
                Text(
                  '${currentSimulationTime!.hour.toString().padLeft(2, '0')}:'
                  '${currentSimulationTime!.minute.toString().padLeft(2, '0')}:'
                  '${currentSimulationTime!.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: AppColors.grey),
                ),
            ],
          ),

          // Slider
          Slider(value: sliderValue, onChanged: onSliderChanged, onChangeStart: onSliderChangeStart, onChangeEnd: onSliderChangeEnd, divisions: totalPoints > 1 ? totalPoints - 1 : 1),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSimulating) ...[
                ElevatedButton.icon(
                  onPressed: onStartSimulation,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(AppStrings.play),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.white),
                ),
              ] else ...[
                if (!isPaused) ...[
                  ElevatedButton.icon(
                    onPressed: onPauseSimulation,
                    icon: const Icon(Icons.pause),
                    label: const Text(AppStrings.pause),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: AppColors.white),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: onResumeSimulation,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(AppStrings.resume),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.white),
                  ),
                ],
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onStopSimulation,
                  icon: const Icon(Icons.stop),
                  label: const Text(AppStrings.stop),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
