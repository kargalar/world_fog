import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import 'route_detail_page.dart';

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
        title: const Text('Rotayı Sil'),
        content: Text('${route.name} rotasını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRoute(route.id);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
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
        title: const Text('Rota Adını Düzenle'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Rota Adı', border: OutlineInputBorder()),
          maxLength: 50,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != route.name) {
                final updatedRoute = RouteModel(id: route.id, name: newName, startTime: route.startTime, endTime: route.endTime, routePoints: route.routePoints, totalDistance: route.totalDistance, totalDuration: route.totalDuration, exploredAreas: route.exploredAreas);
                await RouteService.saveRoute(updatedRoute);
                if (mounted) _loadRoutes();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rota Geçmişi'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Henüz kaydedilmiş rota yok', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Haritada takibi başlatarak rotalarınızı kaydedin',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // İstatistik kartları
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F1F1F) : Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [_buildStatCard('Toplam Rota', '${_routes.length}', Icons.route, Colors.blue), _buildStatCard('Toplam Mesafe', _getTotalDistance(), Icons.straighten, Colors.green), _buildStatCard('Toplam Süre', _getTotalDuration(), Icons.timer, Colors.orange)],
                  ),
                ),
                // Rota listesi
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _routes.length,
                    itemBuilder: (context, index) {
                      final route = _routes[index];
                      return Card(
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
                                  Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(route.formattedDistance),
                                  const SizedBox(width: 16),
                                  Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(route.formattedDuration),
                                ],
                              ),
                              if (route.totalBreakTime.inSeconds > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.coffee, size: 16, color: Colors.orange[600]),
                                    const SizedBox(width: 4),
                                    Text('Mola: ${route.formattedBreakTime}'),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _editRouteName(route), padding: const EdgeInsets.all(0)),
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => RouteDetailPage(route: route)));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirmation(route),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
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
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
