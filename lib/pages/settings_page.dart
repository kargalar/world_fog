import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart';
import '../services/route_service.dart';
// import '../viewmodels/auth_viewmodel.dart';

class SettingsPage extends StatefulWidget {
  final Function(double)? onRadiusChanged;
  final Function(double)? onOpacityChanged;

  const SettingsPage({super.key, this.onRadiusChanged, this.onOpacityChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportRoutes() async {
    setState(() => _isExporting = true);

    try {
      final result = await RouteService.exportRoutes();
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.exportSuccess), backgroundColor: AppColors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.noRoutesToExport), backgroundColor: AppColors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.exportFailed}: $e'), backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importRoutes() async {
    // İmport seçeneklerini göster
    final replaceExisting = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.importOptions),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.merge_type, color: AppColors.green),
              title: const Text(AppStrings.mergeWithExisting),
              subtitle: const Text(AppStrings.mergeDescription),
              onTap: () => Navigator.pop(context, false),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppColors.red),
              title: const Text(AppStrings.replaceExisting),
              subtitle: const Text(AppStrings.replaceDescription),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, null), child: const Text(AppStrings.cancel))],
      ),
    );

    if (replaceExisting == null) return;

    setState(() => _isImporting = true);

    // Tam ekran loading overlay göster
    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (context) => Material(
        child: PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(AppStrings.importing, style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final result = await RouteService.importRoutes(replaceExisting: replaceExisting);

      if (mounted) {
        // Loading dialog'u kapat
        Navigator.of(context).pop();

        if (result.success) {
          // Başarılı mesajını göster ve uygulamayı kapat
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                // Uygulamayı kapat
                SystemNavigator.pop();
              },
              child: AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.green),
                    SizedBox(width: 8),
                    Text(AppStrings.importSuccess),
                  ],
                ),
                content: Text('${result.message}\n\n${AppStrings.appWillClose}'),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Uygulamayı kapat
                      SystemNavigator.pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                    child: const Text(AppStrings.ok),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: AppColors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        // Loading dialog'u kapat
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.importFailed}: $e'), backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
          // // Hesap Bölümü - Google Login
          // Consumer<AuthViewModel>(
          //   builder: (context, authVM, child) {
          //     return Card(
          //       child: Padding(
          //         padding: const EdgeInsets.all(16),
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Row(
          //               children: [
          //                 Icon(Icons.account_circle, color: Theme.of(context).primaryColor),
          //                 const SizedBox(width: 8),
          //                 Text('Hesap', style: Theme.of(context).textTheme.titleLarge),
          //               ],
          //             ),
          //             const SizedBox(height: 16),
          //             if (authVM.isLoading) const Center(child: CircularProgressIndicator()) else if (authVM.isSignedIn) _buildSignedInView(authVM) else _buildSignInButton(authVM),
          //           ],
          //         ),
          //       ),
          //     );
          //   },
          // ),
          // const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          // Data Management - Import/Export
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(AppStrings.dataManagement, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: _isExporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.upload, color: Theme.of(context).primaryColor),
                    title: const Text(AppStrings.exportRoutes),
                    subtitle: const Text(AppStrings.exportRoutesDescription),
                    trailing: ElevatedButton(onPressed: _isExporting ? null : _exportRoutes, child: Text(_isExporting ? AppStrings.loading : AppStrings.exportRoutes)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: _isImporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.download, color: Theme.of(context).primaryColor),
                    title: const Text(AppStrings.importRoutes),
                    subtitle: const Text(AppStrings.importRoutesDescription),
                    trailing: ElevatedButton(onPressed: _isImporting ? null : _importRoutes, child: Text(_isImporting ? AppStrings.loading : AppStrings.importRoutes)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildSignInButton(AuthViewModel authVM) {
  //   return SizedBox(
  //     width: double.infinity,
  //     child: OutlinedButton.icon(
  //       onPressed: () async {
  //         final success = await authVM.signInWithGoogle();
  //         if (!success && mounted && authVM.errorMessage != null) {
  //           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authVM.errorMessage!), backgroundColor: AppColors.red));
  //           authVM.clearError();
  //         }
  //       },
  //       icon: Image.network('https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg', height: 24, width: 24, errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata)),
  //       label: const Text('Google ile Giriş Yap'),
  //       style: OutlinedButton.styleFrom(
  //         padding: const EdgeInsets.symmetric(vertical: 12),
  //         side: BorderSide(color: Theme.of(context).primaryColor),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildSignedInView(AuthViewModel authVM) {
  //   final user = authVM.currentUser!;
  //   return Column(
  //     children: [
  //       ListTile(
  //         leading: user.photoUrl != null ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!)) : const CircleAvatar(child: Icon(Icons.person)),
  //         title: Text(user.displayName ?? 'Kullanıcı'),
  //         subtitle: Text(user.email ?? ''),
  //       ),
  //       const SizedBox(height: 8),
  //       SizedBox(
  //         width: double.infinity,
  //         child: OutlinedButton.icon(
  //           onPressed: () async {
  //             await authVM.signOut();
  //             if (mounted) {
  //               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.signedOut), backgroundColor: AppColors.green));
  //             }
  //           },
  //           icon: const Icon(Icons.logout),
  //           label: Text(AppStrings.signOut),
  //           style: OutlinedButton.styleFrom(
  //             foregroundColor: AppColors.red,
  //             side: const BorderSide(color: AppColors.red),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
}
