import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';

class SettingsPage extends StatefulWidget {
  final Function(double)? onRadiusChanged;
  final Function(double)? onOpacityChanged;

  const SettingsPage({super.key, this.onRadiusChanged, this.onOpacityChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
            child: const Text(AppStrings.clear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('explored_areas');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.exploredAreasCleared), backgroundColor: AppColors.green));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Map Settings - Clear Explored Areas
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
                    leading: const Icon(Icons.clear_all, color: AppColors.red),
                    title: const Text(AppStrings.clearExploredAreas),
                    subtitle: const Text(AppStrings.deleteAllExploredAreas),
                    trailing: ElevatedButton(
                      onPressed: _clearExploredAreas,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
                      child: const Text(AppStrings.clear),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
