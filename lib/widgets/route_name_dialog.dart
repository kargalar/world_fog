import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

/// Route name dialog
class RouteNameDialog extends StatefulWidget {
  final double distance;
  final Duration duration;
  final int pointsCount;
  final Future<void> Function(String) onSave;

  const RouteNameDialog({super.key, required this.distance, required this.duration, required this.pointsCount, required this.onSave});

  @override
  State<RouteNameDialog> createState() => _RouteNameDialogState();
}

class _RouteNameDialogState extends State<RouteNameDialog> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Varsayılan isim önerisi
    _nameController.text = 'Rota ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    // Otomatik odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      return '${hours}s ${minutes}dk';
    } else {
      return '${minutes}dk';
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
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Row(
              children: [
                Icon(Icons.route, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Save Route',
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
                    'Route Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.straighten, 'Distance', _formatDistance(widget.distance)),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.access_time, 'Duration', _formatDuration(widget.duration)),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.location_on, 'Point Count', '${widget.pointsCount}'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name input
            TextField(
              controller: _nameController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: AppStrings.routeName,
                hintText: 'Enter a name for your route',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context);
                  widget.onSave(value.trim());
                }
              },
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
                      Navigator.pop(context);
                      widget.onSave(name);
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
