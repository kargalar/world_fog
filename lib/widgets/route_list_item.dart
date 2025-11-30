import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../pages/route_detail_page.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

class RouteListItem extends StatelessWidget {
  final RouteModel route;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RouteListItem({super.key, required this.route, required this.onEdit, required this.onDelete});

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getWeatherIcon(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.rainy:
        return Icons.umbrella;
      case WeatherCondition.snowy:
        return Icons.ac_unit;
      case WeatherCondition.windy:
        return Icons.air;
      case WeatherCondition.foggy:
        return Icons.foggy;
    }
  }

  String _getWeatherLabel(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return AppStrings.sunny;
      case WeatherCondition.cloudy:
        return AppStrings.cloudy;
      case WeatherCondition.rainy:
        return AppStrings.rainy;
      case WeatherCondition.snowy:
        return AppStrings.snowy;
      case WeatherCondition.windy:
        return AppStrings.windy;
      case WeatherCondition.foggy:
        return AppStrings.foggy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => RouteDetailPage(route: route)));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          title: Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(route.startTime)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.straighten, size: 16, color: AppColors.greyShade700),
                  const SizedBox(width: 4),
                  Text(route.formattedDistance),
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: AppColors.greyShade700),
                  const SizedBox(width: 4),
                  Text(route.formattedDuration),
                ],
              ),
              if (route.totalBreakTime.inSeconds > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.coffee, size: 16, color: AppColors.orangeShade600),
                    const SizedBox(width: 4),
                    Text('${AppStrings.breakLabel} ${route.formattedBreakTime}'),
                  ],
                ),
              ],
              // Hava durumu ve puan bilgisi
              if (route.weather != null || route.rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (route.weather != null) ...[
                      Icon(_getWeatherIcon(route.weather!.condition), size: 16, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text(route.weather!.conditions.map((c) => _getWeatherLabel(c)).join(', ') + (route.weather!.temperature != null ? ' ${route.weather!.temperature!.toStringAsFixed(0)}°C' : ''), style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                      const SizedBox(width: 12),
                    ],
                    if (route.rating != null) ...[...List.generate(route.rating!, (index) => const Icon(Icons.star, size: 14, color: AppColors.amber)), ...List.generate(5 - route.rating!, (index) => const Icon(Icons.star_border, size: 14, color: AppColors.grey))],
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.speed, size: 16, color: AppColors.purple),
                  const SizedBox(width: 4),
                  Text(route.formattedAverageSpeed),
                  if (route.totalAscent > 0) ...[const SizedBox(width: 16), Icon(Icons.trending_up, size: 16, color: AppColors.green), const SizedBox(width: 4), Text(route.formattedAscent)],
                  if (route.totalDescent > 0) ...[const SizedBox(width: 16), Icon(Icons.trending_down, size: 16, color: AppColors.red), const SizedBox(width: 4), Text(route.formattedDescent)],
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, size: 16, color: AppColors.orange),
                  const SizedBox(width: 4),
                  Text('${route.routePoints.length}'),
                  const SizedBox(width: 16),
                  Icon(Icons.photo_camera, size: 16, color: AppColors.deepPurple),
                  const SizedBox(width: 4),
                  Text('${route.waypoints.length}'),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: onEdit, padding: const EdgeInsets.all(0)),

              IconButton(
                icon: const Icon(Icons.delete, color: AppColors.red),
                onPressed: onDelete,
              ),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}
