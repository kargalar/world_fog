import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

/// Route save bottom sheet - replaces RouteNameDialog
class RouteSaveBottomSheet extends StatefulWidget {
  final double distance;
  final Duration duration;
  final int pointsCount;
  final double totalAscent;
  final double totalDescent;
  final double averageSpeed;
  final Duration totalBreakTime;
  final int waypointsCount;
  final Future<void> Function(String name, List<WeatherCondition>? weatherConditions, double? temperature, int? rating) onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const RouteSaveBottomSheet({
    super.key,
    required this.distance,
    required this.duration,
    required this.pointsCount,
    this.totalAscent = 0.0,
    this.totalDescent = 0.0,
    this.averageSpeed = 0.0,
    this.totalBreakTime = Duration.zero,
    this.waypointsCount = 0,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  State<RouteSaveBottomSheet> createState() => _RouteSaveBottomSheetState();
}

class _RouteSaveBottomSheetState extends State<RouteSaveBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final Set<WeatherCondition> _selectedWeatherConditions = {};
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    _nameController.text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _temperatureController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distance.toStringAsFixed(0)} m';
    }
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '$hours${AppStrings.hourUnit} $minutes${AppStrings.minuteUnit}';
    } else if (minutes > 0) {
      return '$minutes${AppStrings.minuteUnit} $seconds${AppStrings.secondUnit}';
    } else {
      return '$seconds${AppStrings.secondUnit}';
    }
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

  Color _getWeatherColor(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return AppColors.orange;
      case WeatherCondition.cloudy:
        return AppColors.grey;
      case WeatherCondition.rainy:
        return AppColors.blue;
      case WeatherCondition.snowy:
        return AppColors.lightBlue;
      case WeatherCondition.windy:
        return AppColors.teal;
      case WeatherCondition.foggy:
        return AppColors.blueGrey;
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.deleteRouteTurkish),
        content: Text(AppStrings.confirmDeleteRouteMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onDelete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
            child: Text(AppStrings.deleteTurkish),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.greyShade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Icon(Icons.route, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(AppStrings.saveRoute, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Route details - All details in compact grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.routeDetails,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  // First row: Distance, Duration, Avg Speed
                  Row(
                    children: [
                      Expanded(child: _buildCompactDetail(Icons.straighten, AppStrings.distance, _formatDistance(widget.distance), AppColors.blue)),
                      Expanded(child: _buildCompactDetail(Icons.timer, AppStrings.duration, _formatDuration(widget.duration), AppColors.green)),
                      Expanded(child: _buildCompactDetail(Icons.speed, AppStrings.averageSpeed, '${widget.averageSpeed.toStringAsFixed(1)} km/h', AppColors.purple)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Second row: Ascent, Descent, Break time
                  Row(
                    children: [
                      Expanded(child: _buildCompactDetail(Icons.trending_up, AppStrings.ascent, '${widget.totalAscent.toStringAsFixed(0)}m', AppColors.green)),
                      Expanded(child: _buildCompactDetail(Icons.trending_down, AppStrings.descent, '${widget.totalDescent.toStringAsFixed(0)}m', AppColors.red)),
                      Expanded(child: _buildCompactDetail(Icons.coffee, AppStrings.breakTime, _formatDuration(widget.totalBreakTime), AppColors.brown)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Third row: Points count, Waypoints count
                  Row(
                    children: [
                      Expanded(child: _buildCompactDetail(Icons.location_on, AppStrings.points, '${widget.pointsCount}', AppColors.orange)),
                      Expanded(child: _buildCompactDetail(Icons.photo_camera, AppStrings.waypointsLabel, '${widget.waypointsCount}', AppColors.deepPurple)),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Name input
            TextField(
              controller: _nameController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: AppStrings.routeName,
                hintText: AppStrings.enterRouteNameHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Weather selection - Compact with multi-select
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud, size: 16),
                      const SizedBox(width: 6),
                      Text(AppStrings.weather, style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      if (_selectedWeatherConditions.isNotEmpty)
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: _temperatureController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '°C',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: WeatherCondition.values.map((condition) {
                      final isSelected = _selectedWeatherConditions.contains(condition);
                      return FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getWeatherIcon(condition), size: 14, color: isSelected ? AppColors.white : _getWeatherColor(condition)),
                            const SizedBox(width: 3),
                            Text(_getWeatherLabel(condition), style: TextStyle(fontSize: 11, color: isSelected ? AppColors.white : null)),
                          ],
                        ),
                        selectedColor: _getWeatherColor(condition),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedWeatherConditions.add(condition);
                            } else {
                              _selectedWeatherConditions.remove(condition);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Rating - Compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 16, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Text(AppStrings.rating, style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  ...List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _rating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(index < _rating ? Icons.star : Icons.star_border, color: AppColors.amber, size: 28),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons - Delete, Cancel, Save
            Row(
              children: [
                // Delete button
                IconButton(onPressed: _confirmDelete, icon: const Icon(Icons.delete_outline), color: AppColors.red, tooltip: AppStrings.deleteRouteTooltip),
                const Spacer(),
                // Cancel button
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCancel();
                  },
                  child: Text(AppStrings.cancel),
                ),
                const SizedBox(width: 8),
                // Save button
                FilledButton(
                  onPressed: () {
                    String name = _nameController.text.trim();
                    if (name.isEmpty) {
                      name = AppStrings.untitled;
                    }
                    double? temp;
                    if (_temperatureController.text.isNotEmpty) {
                      temp = double.tryParse(_temperatureController.text);
                    }
                    Navigator.pop(context);
                    widget.onSave(name, _selectedWeatherConditions.isNotEmpty ? _selectedWeatherConditions.toList() : null, temp, _rating > 0 ? _rating : null);
                  },
                  child: Text(AppStrings.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDetail(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.grey)),
        Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Show route save bottom sheet
void showRouteSaveBottomSheet({
  required BuildContext context,
  required double distance,
  required Duration duration,
  required int pointsCount,
  double totalAscent = 0.0,
  double totalDescent = 0.0,
  double averageSpeed = 0.0,
  Duration totalBreakTime = Duration.zero,
  int waypointsCount = 0,
  required Future<void> Function(String name, List<WeatherCondition>? weatherConditions, double? temperature, int? rating) onSave,
  required VoidCallback onDelete,
  required VoidCallback onCancel,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (context) =>
        RouteSaveBottomSheet(distance: distance, duration: duration, pointsCount: pointsCount, totalAscent: totalAscent, totalDescent: totalDescent, averageSpeed: averageSpeed, totalBreakTime: totalBreakTime, waypointsCount: waypointsCount, onSave: onSave, onDelete: onDelete, onCancel: onCancel),
  );
}
