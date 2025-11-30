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
  final int pointsCount;
  final int waypointsCount;

  const RouteStatsCard({super.key, required this.currentRouteDistance, required this.currentRouteDuration, required this.currentBreakDuration, required this.isPaused, this.averageSpeed = 0.0, this.totalAscent = 0.0, this.totalDescent = 0.0, this.pointsCount = 0, this.waypointsCount = 0});

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
                if (isPaused) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      AppStrings.paused,
                      style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            // İlk satır: Mesafe, Süre, Mola
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(AppStrings.distance, _formatDistance(currentRouteDistance), Icons.straighten, AppColors.blue),
                _buildStatItem(AppStrings.duration, _formatDuration(currentRouteDuration), Icons.timer, AppColors.green),
                _buildStatItem(AppStrings.breakTime, _formatDuration(currentBreakDuration), Icons.coffee, AppColors.orange),
              ],
            ),
            const SizedBox(height: 12),
            // İkinci satır: Ortalama Hız, Çıkış, İniş
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(AppStrings.averageSpeed, '${averageSpeed.toStringAsFixed(1)} ${AppStrings.kmPerHour}', Icons.speed, AppColors.purple),
                _buildStatItem(AppStrings.ascent, '${totalAscent.toStringAsFixed(0)}${AppStrings.metersUnit}', Icons.trending_up, AppColors.green),
                _buildStatItem(AppStrings.descent, '${totalDescent.toStringAsFixed(0)}${AppStrings.metersUnit}', Icons.trending_down, AppColors.red),
              ],
            ),
            const SizedBox(height: 12),
            // Üçüncü satır: Nokta Sayısı, İşaret Sayısı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(AppStrings.points, '$pointsCount', Icons.location_on, AppColors.orange),
                _buildStatItem(AppStrings.waypointsLabel, '$waypointsCount', Icons.photo_camera, AppColors.deepPurple),
                const SizedBox(), // Boş yer için
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
      return '${distance.toStringAsFixed(0)} ${AppStrings.metersUnit}';
    } else {
      return '${(distance / 1000).toStringAsFixed(2)} ${AppStrings.km}';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours${AppStrings.hourUnit} ${minutes.toString().padLeft(2, '0')}${AppStrings.minuteUnit} ${seconds.toString().padLeft(2, '0')}${AppStrings.secondUnit}';
    } else if (minutes > 0) {
      return '$minutes${AppStrings.minuteUnit} ${seconds.toString().padLeft(2, '0')}${AppStrings.secondUnit}';
    } else {
      return '$seconds${AppStrings.secondUnit}';
    }
  }
}
