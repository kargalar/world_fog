import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final Function(double)? onRadiusChanged;
  final Function(double)? onOpacityChanged;

  const SettingsPage({super.key, required this.onThemeChanged, this.onRadiusChanged, this.onOpacityChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _currentTheme = ThemeMode.system;
  double _explorationRadius = 50.0;
  double _areaOpacity = 0.3;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    final radius = prefs.getDouble('exploration_radius') ?? 50.0;
    final opacity = prefs.getDouble('area_opacity') ?? 0.3;

    setState(() {
      _currentTheme = ThemeMode.values[themeIndex];
      _explorationRadius = radius;
      _areaOpacity = opacity;
    });
  }

  Future<void> _saveTheme(ThemeMode theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', theme.index);
    setState(() {
      _currentTheme = theme;
    });
    widget.onThemeChanged(theme);
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
        title: const Text('Keşfedilen Alanları Temizle'),
        content: const Text('Tüm keşfedilen alanları silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('explored_areas');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keşfedilen alanlar temizlendi'), backgroundColor: Colors.green));
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
          decoration: BoxDecoration(color: color.withOpacity(0.7), shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tema Ayarları
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text('Tema Ayarları', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<ThemeMode>(title: const Text('Sistem Teması'), subtitle: const Text('Cihazın tema ayarını takip eder'), value: ThemeMode.system, groupValue: _currentTheme, onChanged: (value) => _saveTheme(value!)),
                  RadioListTile<ThemeMode>(title: const Text('Açık Tema'), subtitle: const Text('Her zaman açık tema kullan'), value: ThemeMode.light, groupValue: _currentTheme, onChanged: (value) => _saveTheme(value!)),
                  RadioListTile<ThemeMode>(title: const Text('Koyu Tema'), subtitle: const Text('Her zaman koyu tema kullan'), value: ThemeMode.dark, groupValue: _currentTheme, onChanged: (value) => _saveTheme(value!)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Keşif Ayarları
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
                      Text('Keşif Ayarları', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Keşif Yarıçapı: ${_explorationRadius >= 1000 ? '${(_explorationRadius / 1000).toStringAsFixed(1)} km' : '${_explorationRadius.toInt()} metre'}', style: Theme.of(context).textTheme.titleMedium),
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
                  const Text('Bu ayar, bir noktanın keşfedilmiş sayılması için gereken minimum mesafeyi belirler. Daha büyük yarıçap daha geniş alanları keşfetmenizi sağlar.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Keşfedilen Alanların Görünürlüğü: %${(_areaOpacity * 100).toInt()}', style: Theme.of(context).textTheme.titleMedium),
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
                  const Text('Bu ayar, keşfedilen alanların haritada ne kadar belirgin görüneceğini belirler. Düşük değerler haritanın daha net görünmesini sağlar.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Harita Ayarları
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
                      Text('Harita Ayarları', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.clear_all, color: Colors.red),
                    title: const Text('Keşfedilen Alanları Temizle'),
                    subtitle: const Text('Tüm keşfedilmiş alanları haritadan siler'),
                    trailing: ElevatedButton(
                      onPressed: _clearExploredAreas,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Temizle'),
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
                      Text('Uygulama Bilgileri', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ListTile(leading: Icon(Icons.apps), title: Text('Uygulama Adı'), subtitle: Text('World Fog - Keşif Haritası')),
                  const ListTile(leading: Icon(Icons.info_outline), title: Text('Versiyon'), subtitle: Text('1.0.0')),
                  const ListTile(leading: Icon(Icons.description), title: Text('Açıklama'), subtitle: Text('Gezdiğiniz yerleri keşfederek haritada görselleştirin')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Renk legend'ı
          Text('Keşif Frekansı Renk Haritası', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [_buildColorLegend('İlk kez', Colors.blue), _buildColorLegend('2-3 kez', Colors.lightBlue), _buildColorLegend('4-5 kez', Colors.teal), _buildColorLegend('6-7 kez', Colors.green), _buildColorLegend('8-9 kez', Colors.yellow), _buildColorLegend('10+ kez', Colors.red)],
          ),
          const SizedBox(height: 8),
          const Text('Keşfedilen alanlar, sıklığa göre mavi (az) ile kırmızı (çok) arasında renk alır.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
