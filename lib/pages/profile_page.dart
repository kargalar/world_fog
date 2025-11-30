import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';
import '../widgets/route_list_item.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<RouteModel> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
    });

    final routes = await RouteService.getSavedRoutes();
    setState(() {
      _routes = routes..sort((a, b) => b.startTime.compareTo(a.startTime));
      _isLoading = false;
    });
  }

  Future<void> _deleteRoute(String routeId) async {
    await RouteService.deleteRoute(routeId);
    _loadRoutes();
  }

  void _showDeleteConfirmation(RouteModel route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteRoute),
        content: Text('${AppStrings.confirmDeleteRoute} ${route.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppStrings.cancel)),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRoute(route.id);
            },
            child: const Text(AppStrings.delete, style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _editRouteName(RouteModel route) {
    final TextEditingController nameController = TextEditingController();
    nameController.text = route.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.editRouteName),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: AppStrings.routeName, border: OutlineInputBorder()),
          maxLength: 50,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != route.name) {
                final updatedRoute = RouteModel(id: route.id, name: newName, startTime: route.startTime, endTime: route.endTime, routePoints: route.routePoints, totalDistance: route.totalDistance, totalDuration: route.totalDuration, exploredAreas: route.exploredAreas);
                await RouteService.saveRoute(updatedRoute);
                if (mounted) _loadRoutes();
              }
              // ignore: use_build_context_synchronously
              if (mounted) Navigator.pop(context);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
            tooltip: AppStrings.settings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 64, color: AppColors.grey),
                  SizedBox(height: 16),
                  Text(AppStrings.noSavedRoutes, style: TextStyle(fontSize: 18, color: AppColors.grey)),
                  SizedBox(height: 8),
                  Text(
                    AppStrings.startTrackingToSave,
                    style: TextStyle(fontSize: 14, color: AppColors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Statistics cards
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F1F1F) : AppColors.greyShade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(AppStrings.totalRoutes, '${_routes.length}', Icons.route, AppColors.blue),
                      _buildStatCard(AppStrings.totalDistance, _getTotalDistance(), Icons.straighten, AppColors.green),
                      _buildStatCard(AppStrings.totalTime, _getTotalDuration(), Icons.timer, AppColors.orange),
                    ],
                  ),
                ),
                // Route list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _routes.length,
                    itemBuilder: (context, index) {
                      final route = _routes[index];
                      return RouteListItem(route: route, onEdit: () => _editRouteName(route), onDelete: () => _showDeleteConfirmation(route));
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _getTotalDistance() {
    final total = _routes.fold(0.0, (sum, route) => sum + route.totalDistance);
    if (total < 1000) {
      return '${total.toStringAsFixed(0)} m';
    } else {
      return '${(total / 1000).toStringAsFixed(2)} km';
    }
  }

  String _getTotalDuration() {
    final total = _routes.fold(Duration.zero, (sum, route) => sum + route.totalDuration);
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;

    if (hours > 0) {
      return '${hours}s ${minutes}d';
    } else {
      return '${minutes}d';
    }
  }
}
