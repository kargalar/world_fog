import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

class RouteStatsCard extends StatelessWidget {
  final double currentRouteDistance;
  final Duration currentRouteDuration;
  final Duration currentBreakDuration;
  final bool isPaused;

  const RouteStatsCard({super.key, required this.currentRouteDistance, required this.currentRouteDuration, required this.currentBreakDuration, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(AppStrings.activeRoute, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Distance', _formatDistance(currentRouteDistance), Icons.straighten, Colors.blue),
                _buildStatItem('Duration', _formatDuration(currentRouteDuration), Icons.timer, Colors.green),
                if (isPaused || currentBreakDuration.inSeconds > 0) _buildStatItem('Break', _formatDuration(currentBreakDuration), Icons.coffee, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}s ${minutes.toString().padLeft(2, '0')}d';
    } else if (minutes > 0) {
      return '${minutes}d ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }
}
