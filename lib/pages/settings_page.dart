import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_strings.dart';

class SettingsPage extends StatefulWidget {
  final Function(double)? onRadiusChanged;
  final Function(double)? onOpacityChanged;

  const SettingsPage({super.key, this.onRadiusChanged, this.onOpacityChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _explorationRadius = 50.0;
  double _areaOpacity = 0.3;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final radius = prefs.getDouble('exploration_radius') ?? 50.0;
    final opacity = prefs.getDouble('area_opacity') ?? 0.3;

    setState(() {
      _explorationRadius = radius;
      _areaOpacity = opacity;
    });
  }

  Future<void> _saveRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('exploration_radius', radius);
    setState(() {
      _explorationRadius = radius;
    });
    // Ana sayfaya değişikliği bildir
    widget.onRadiusChanged?.call(radius);
  }

  Future<void> _saveOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('area_opacity', opacity);
    setState(() {
      _areaOpacity = opacity;
    });
    // Ana sayfaya değişikliği bildir
    widget.onOpacityChanged?.call(opacity);
  }

  Future<void> _clearExploredAreas() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.clearExploredAreas),
        content: const Text(AppStrings.confirmClearExploredAreas),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text(AppStrings.clear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('explored_areas');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.exploredAreasCleared), backgroundColor: Colors.green));
      }
    }
  }

  Widget _buildColorLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color.withAlpha(179), shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Exploration Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.explore, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(AppStrings.explorationSettings, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('${AppStrings.explorationRadius}: ${_explorationRadius >= 1000 ? '${(_explorationRadius / 1000).toStringAsFixed(1)} km' : '${_explorationRadius.toInt()} ${AppStrings.meters}'}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Slider(
                    value: _explorationRadius,
                    min: 20,
                    max: 1000,
                    divisions: 49, // 20 divisions for 20-100, 18 divisions for 100-1000 (50m steps)
                    label: _explorationRadius >= 1000 ? '${(_explorationRadius / 1000).toStringAsFixed(1)}km' : '${_explorationRadius.toInt()}m',
                    onChanged: (value) {
                      setState(() {
                        // 100m'ye kadar 5m aralıklarla, sonrasında 50m aralıklarla
                        if (value <= 100) {
                          _explorationRadius = (value / 5).round() * 5.0;
                        } else {
                          _explorationRadius = (value / 50).round() * 50.0;
                        }
                      });
                    },
                    onChangeEnd: (value) {
                      _saveRadius(_explorationRadius);
                    },
                  ),
                  const Text(AppStrings.explorationRadiusDescription, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('${AppStrings.exploredAreasVisibility}: %${(_areaOpacity * 100).toInt()}', style: Theme.of(context).textTheme.titleMedium),
                  Slider(
                    value: _areaOpacity,
                    min: 0.05,
                    max: 0.8,
                    divisions: 15,
                    label: '%${(_areaOpacity * 100).toInt()}',
                    onChanged: (value) {
                      setState(() {
                        _areaOpacity = value;
                      });
                    },
                    onChangeEnd: (value) {
                      _saveOpacity(value);
                    },
                  ),
                  const Text(AppStrings.exploredAreasVisibilityDescription, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Map Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(AppStrings.mapSettings, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.clear_all, color: Colors.red),
                    title: const Text(AppStrings.clearExploredAreas),
                    subtitle: const Text(AppStrings.deleteAllExploredAreas),
                    trailing: ElevatedButton(
                      onPressed: _clearExploredAreas,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text(AppStrings.clear),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(AppStrings.appInfo, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ListTile(leading: Icon(Icons.apps), title: Text(AppStrings.appNameLabel), subtitle: Text(AppStrings.appDescription)),
                  const ListTile(leading: Icon(Icons.info_outline), title: Text(AppStrings.versionLabel), subtitle: Text(AppStrings.version)),
                  const ListTile(leading: Icon(Icons.description), title: Text(AppStrings.descriptionLabel), subtitle: Text(AppStrings.appFullDescription)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Color legend
          Text(AppStrings.explorationFrequencyColorMap, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildColorLegend(AppStrings.firstTime, Colors.blue),
              _buildColorLegend(AppStrings.twoToThreeTimes, Colors.lightBlue),
              _buildColorLegend(AppStrings.fourToFiveTimes, Colors.teal),
              _buildColorLegend(AppStrings.sixToSevenTimes, Colors.green),
              _buildColorLegend(AppStrings.eightToNineTimes, Colors.yellow),
              _buildColorLegend(AppStrings.tenPlusTimes, Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          const Text(AppStrings.colorMapDescription, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
