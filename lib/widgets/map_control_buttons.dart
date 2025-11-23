import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

class MapControlButtons extends StatelessWidget {
  final VoidCallback? onLocationPressed;
  final VoidCallback? onTogglePastRoutes;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onSettingsPressed;
  final bool isFollowingLocation;
  final bool showPastRoutes;

  const MapControlButtons({super.key, this.onLocationPressed, this.onTogglePastRoutes, this.onProfilePressed, this.onSettingsPressed, required this.isFollowingLocation, required this.showPastRoutes});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        children: [
          _buildControlButton(icon: isFollowingLocation ? Icons.gps_fixed : Icons.gps_not_fixed, onPressed: onLocationPressed, backgroundColor: isFollowingLocation ? Colors.blue : Colors.white, iconColor: isFollowingLocation ? Colors.white : Colors.grey, tooltip: AppStrings.followMyLocation),
          const SizedBox(height: 8),
          _buildControlButton(icon: showPastRoutes ? Icons.visibility_off : Icons.visibility, onPressed: onTogglePastRoutes, backgroundColor: showPastRoutes ? Colors.orange : Colors.white, iconColor: showPastRoutes ? Colors.white : Colors.grey, tooltip: AppStrings.pastRoutes),
          const SizedBox(height: 8),
          _buildControlButton(icon: Icons.person, onPressed: onProfilePressed, backgroundColor: Colors.white, iconColor: Colors.grey, tooltip: AppStrings.profile),
          const SizedBox(height: 8),
          _buildControlButton(icon: Icons.settings, onPressed: onSettingsPressed, backgroundColor: Colors.white, iconColor: Colors.grey, tooltip: AppStrings.settings),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback? onPressed, required Color backgroundColor, required Color iconColor, required String tooltip}) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 24,
      ),
    );
  }
}
