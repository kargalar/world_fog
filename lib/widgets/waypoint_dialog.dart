import 'dart:io';
import 'package:flutter/material.dart';
import '../models/route_model.dart';

/// Waypoint tipi seçimi için dialog
class WaypointTypeDialog extends StatefulWidget {
  final String photoPath;

  const WaypointTypeDialog({super.key, required this.photoPath});

  @override
  State<WaypointTypeDialog> createState() => _WaypointTypeDialogState();
}

class _WaypointTypeDialogState extends State<WaypointTypeDialog> {
  WaypointType _selectedType = WaypointType.scenery;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  IconData _getTypeIcon(WaypointType type) {
    switch (type) {
      case WaypointType.scenery:
        return Icons.landscape;
      case WaypointType.fountain:
        return Icons.water_drop;
      case WaypointType.junction:
        return Icons.fork_right;
      case WaypointType.waterfall:
        return Icons.waterfall_chart;
      case WaypointType.other:
        return Icons.place;
    }
  }

  Color _getTypeColor(WaypointType type) {
    switch (type) {
      case WaypointType.scenery:
        return Colors.green;
      case WaypointType.fountain:
        return Colors.blue;
      case WaypointType.junction:
        return Colors.orange;
      case WaypointType.waterfall:
        return Colors.cyan;
      case WaypointType.other:
        return Colors.purple;
    }
  }

  String _getTypeLabel(WaypointType type) {
    switch (type) {
      case WaypointType.scenery:
        return 'Manzara';
      case WaypointType.fountain:
        return 'Çeşme';
      case WaypointType.junction:
        return 'Yol Ayrımı';
      case WaypointType.waterfall:
        return 'Şelale';
      case WaypointType.other:
        return 'Diğer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  const Icon(Icons.add_location, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text('İşaret Ekle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),

              // Fotoğraf önizleme
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.file(File(widget.photoPath), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),

              // İşaret tipi seçimi
              Text('İşaret Tipi', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WaypointType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getTypeIcon(type), size: 18, color: isSelected ? Colors.white : _getTypeColor(type)),
                        const SizedBox(width: 6),
                        Text(_getTypeLabel(type), style: TextStyle(color: isSelected ? Colors.white : null)),
                      ],
                    ),
                    selectedColor: _getTypeColor(type),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedType = type;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Açıklama
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Açıklama (Opsiyonel)',
                  hintText: 'Bu yer hakkında bir not ekleyin...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context, {'type': _selectedType, 'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null});
                    },
                    child: const Text('Ekle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Waypoint detaylarını gösteren bottom sheet
class WaypointDetailSheet extends StatelessWidget {
  final RouteWaypoint waypoint;
  final VoidCallback? onDelete;

  const WaypointDetailSheet({super.key, required this.waypoint, this.onDelete});

  IconData _getTypeIcon(WaypointType type) {
    switch (type) {
      case WaypointType.scenery:
        return Icons.landscape;
      case WaypointType.fountain:
        return Icons.water_drop;
      case WaypointType.junction:
        return Icons.fork_right;
      case WaypointType.waterfall:
        return Icons.waterfall_chart;
      case WaypointType.other:
        return Icons.place;
    }
  }

  Color _getTypeColor(WaypointType type) {
    switch (type) {
      case WaypointType.scenery:
        return Colors.green;
      case WaypointType.fountain:
        return Colors.blue;
      case WaypointType.junction:
        return Colors.orange;
      case WaypointType.waterfall:
        return Colors.cyan;
      case WaypointType.other:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Başlık
          Row(
            children: [
              Icon(_getTypeIcon(waypoint.type), color: _getTypeColor(waypoint.type), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(waypoint.typeLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text(_formatDateTime(waypoint.timestamp), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Fotoğraf
          if (waypoint.photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(waypoint.photoPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                    );
                  },
                ),
              ),
            ),

          // Açıklama
          if (waypoint.description != null && waypoint.description!.isNotEmpty) ...[const SizedBox(height: 16), Text(waypoint.description!, style: Theme.of(context).textTheme.bodyMedium)],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
