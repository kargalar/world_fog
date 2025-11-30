import 'package:flutter/material.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

class RouteStatsCard extends StatelessWidget {
  final double currentRouteDistance;
  final Duration currentRouteDuration;
  final Duration currentBreakDuration;
  final bool isPaused;
  final double averageSpeed;
  final double totalAscent;
  final double totalDescent;

  const RouteStatsCard({super.key, required this.currentRouteDistance, required this.currentRouteDuration, required this.currentBreakDuration, required this.isPaused, this.averageSpeed = 0.0, this.totalAscent = 0.0, this.totalDescent = 0.0});

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
                if (isPaused) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      'Durakladı',
                      style: TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // İlk satır: Mesafe, Süre, Mola
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Mesafe', _formatDistance(currentRouteDistance), Icons.straighten, AppColors.blue),
                _buildStatItem('Süre', _formatDuration(currentRouteDuration), Icons.timer, AppColors.green),
                _buildStatItem('Mola', _formatDuration(currentBreakDuration), Icons.coffee, AppColors.orange),
              ],
            ),
            const SizedBox(height: 12),
            // İkinci satır: Ortalama Hız, Çıkış, İniş
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Ort. Hız', '${averageSpeed.toStringAsFixed(1)} km/h', Icons.speed, AppColors.purple),
                _buildStatItem('Çıkış', '${totalAscent.toStringAsFixed(0)}m', Icons.trending_up, AppColors.green),
                _buildStatItem('İniş', '${totalDescent.toStringAsFixed(0)}m', Icons.trending_down, AppColors.red),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.grey)),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
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
      return '${hours}s ${minutes.toString().padLeft(2, '0')}d ${seconds.toString().padLeft(2, '0')}s';
    } else if (minutes > 0) {
      return '${minutes}d ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }
}
