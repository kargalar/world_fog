import 'package:flutter/material.dart';

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
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F1F1F) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zaman ve ilerleme bilgisi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('İlerleme: ${currentPointIndex + 1} / $totalPoints', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (currentSimulationTime != null)
                Text(
                  '${currentSimulationTime!.hour.toString().padLeft(2, '0')}:'
                  '${currentSimulationTime!.minute.toString().padLeft(2, '0')}:'
                  '${currentSimulationTime!.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),

          // Slider
          Slider(value: sliderValue, onChanged: onSliderChanged, onChangeStart: onSliderChangeStart, onChangeEnd: onSliderChangeEnd, divisions: totalPoints > 1 ? totalPoints - 1 : 1),

          // Kontrol butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSimulating) ...[
                ElevatedButton.icon(
                  onPressed: onStartSimulation,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Oynat'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ] else ...[
                if (!isPaused) ...[
                  ElevatedButton.icon(
                    onPressed: onPauseSimulation,
                    icon: const Icon(Icons.pause),
                    label: const Text('Duraklat'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: onResumeSimulation,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Devam'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ],
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onStopSimulation,
                  icon: const Icon(Icons.stop),
                  label: const Text('Durdur'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
