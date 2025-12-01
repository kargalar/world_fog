import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

/// Route name dialog
class RouteNameDialog extends StatefulWidget {
  final double distance;
  final Duration duration;
  final int pointsCount;
  final double totalAscent;
  final double totalDescent;
  final double averageSpeed;
  final Future<void> Function(String name, WeatherInfo? weather, int? rating) onSave;

  const RouteNameDialog({super.key, required this.distance, required this.duration, required this.pointsCount, this.totalAscent = 0.0, this.totalDescent = 0.0, this.averageSpeed = 0.0, required this.onSave});

  @override
  State<RouteNameDialog> createState() => _RouteNameDialogState();
}

class _RouteNameDialogState extends State<RouteNameDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  WeatherCondition? _selectedWeather;
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    // Varsayılan isim önerisi
    _nameController.text = 'Route ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    // Otomatik odaklan
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
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  Icon(Icons.route, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.saveRoute,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Rota detayları
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.routeDetails,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.straighten, 'Mesafe', _formatDistance(widget.distance)),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.access_time, AppStrings.duration, _formatDuration(widget.duration)),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.speed, AppStrings.avgSpeed, '${widget.averageSpeed.toStringAsFixed(1)} km/h'),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.location_on, AppStrings.pointCount, '${widget.pointsCount}'),
                    if (widget.totalAscent > 0 || widget.totalDescent > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDetailRow(Icons.trending_up, AppStrings.ascent, '${widget.totalAscent.toStringAsFixed(0)}m')),
                          Expanded(child: _buildDetailRow(Icons.trending_down, AppStrings.descent, '${widget.totalDescent.toStringAsFixed(0)}m')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Name input
              TextField(
                controller: _nameController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: AppStrings.routeName,
                  hintText: AppStrings.enterRouteNameHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              const SizedBox(height: 20),

              // Hava durumu seçimi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud, size: 20),
                        const SizedBox(width: 8),
                        Text(AppStrings.weather, style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WeatherCondition.values.map((condition) {
                        final isSelected = _selectedWeather == condition;
                        return FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getWeatherIcon(condition), size: 16, color: isSelected ? AppColors.white : _getWeatherColor(condition)),
                              const SizedBox(width: 4),
                              Text(
                                condition == WeatherCondition.sunny
                                    ? AppStrings.sunny
                                    : condition == WeatherCondition.cloudy
                                    ? AppStrings.cloudy
                                    : condition == WeatherCondition.rainy
                                    ? AppStrings.rainy
                                    : condition == WeatherCondition.snowy
                                    ? AppStrings.snowy
                                    : condition == WeatherCondition.windy
                                    ? AppStrings.windy
                                    : AppStrings.foggy,
                                style: TextStyle(fontSize: 12, color: isSelected ? AppColors.white : null),
                              ),
                            ],
                          ),
                          selectedColor: _getWeatherColor(condition),
                          onSelected: (selected) {
                            setState(() {
                              _selectedWeather = selected ? condition : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_selectedWeather != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _temperatureController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: AppStrings.temperature,
                            suffixText: '°C',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Puanlama
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 20, color: AppColors.amber),
                        const SizedBox(width: 8),
                        Text(AppStrings.rateRoute, style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(index < _rating ? Icons.star : Icons.star_border, color: AppColors.amber, size: 32),
                          onPressed: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(AppStrings.cancel, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      final name = _nameController.text.trim();
                      if (name.isNotEmpty) {
                        WeatherInfo? weather;
                        if (_selectedWeather != null) {
                          double? temp;
                          if (_temperatureController.text.isNotEmpty) {
                            temp = double.tryParse(_temperatureController.text);
                          }
                          weather = WeatherInfo(condition: _selectedWeather!, temperature: temp);
                        }
                        Navigator.pop(context);
                        widget.onSave(name, weather, _rating > 0 ? _rating : null);
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(AppStrings.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }
}
