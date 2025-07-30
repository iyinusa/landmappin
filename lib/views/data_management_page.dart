import 'dart:io';
import 'package:flutter/material.dart';
import '../services/data_export_import_service.dart';
import '../widgets/animated_action_card.dart';
import '../widgets/animated_dialog.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _importDemoData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final result = await DataExportImportService.importDemoData();

      setState(() {
        _isLoading = false;
        _statusMessage = result.message;
      });

      if (result.success) {
        _showSuccessDialog(
          'Demo Data Imported',
          'Successfully imported ${result.projectsImported} projects and ${result.pointsImported} mapping points.',
        );
      } else {
        _showErrorDialog('Import Failed', result.message);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
      _showErrorDialog('Import Error', e.toString());
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final file = await DataExportImportService.exportData();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Data exported successfully';
      });

      // Show success dialog with share option
      _showExportSuccessDialog(file);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Export error: ${e.toString()}';
      });
      _showErrorDialog('Export Error', e.toString());
    }
  }

  Future<void> _importData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'This feature will be available in a future update.';
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    _showInfoDialog(
      'Coming Soon',
      'File import functionality will be available in a future update. For now, use the demo data to get started.',
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showConfirmationDialog(
      'Clear All Data',
      'Are you sure you want to delete all projects and mapping points? This action cannot be undone.',
    );

    if (confirmed) {
      setState(() {
        _isLoading = true;
        _statusMessage = null;
      });

      try {
        await DataExportImportService.clearAllData();

        setState(() {
          _isLoading = false;
          _statusMessage = 'All data cleared successfully';
        });

        _showSuccessDialog('Data Cleared',
            'All projects and mapping points have been deleted.');
      } catch (e) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error clearing data: ${e.toString()}';
        });
        _showErrorDialog('Clear Error', e.toString());
      }
    }
  }

  void _showSuccessDialog(String title, String message) {
    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.check_circle_outline,
        color: Colors.green,
        size: 48,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        ModernDialogButton(
          text: 'OK',
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showInfoDialog(String title, String message) {
    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.info_outline,
        color: Colors.blue,
        size: 48,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        ModernDialogButton(
          text: 'OK',
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showErrorDialog(String title, String message) {
    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.error_outline,
        color: Colors.red,
        size: 48,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        ModernDialogButton(
          text: 'OK',
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showExportSuccessDialog(File file) {
    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.cloud_done_outlined,
        color: Colors.green,
        size: 48,
      ),
      title: const Text('Export Successful'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your data has been exported successfully.'),
          const SizedBox(height: 8),
          Text(
            'File: ${file.path}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      actions: [
        ModernDialogButton(
          text: 'OK',
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await ModernAlertDialog.show<bool>(
      context: context,
      icon: const Icon(
        Icons.warning_outlined,
        color: Colors.orange,
        size: 48,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        ModernDialogButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        ModernDialogButton(
          text: 'Delete',
          isDestructive: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Data Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Demo Data Section
                const Text(
                  'Demo Data',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Import sample projects to get started with LandMappin.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedActionCard(
                  icon: Icons.download,
                  title: 'Import Demo Data',
                  subtitle: 'Load sample projects with mapping points',
                  onTap: _importDemoData,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 32),

                // Data Management Section
                const Text(
                  'Data Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Export your projects or import data from other devices.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                AnimatedActionCard(
                  icon: Icons.upload,
                  title: 'Export Data',
                  subtitle: 'Save all projects and points to JSON file',
                  onTap: _exportData,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),

                AnimatedActionCard(
                  icon: Icons.file_download,
                  title: 'Import Data',
                  subtitle: 'Load projects from JSON file',
                  onTap: _importData,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 32),

                // Danger Zone
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Irreversible actions that will permanently delete your data.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                AnimatedActionCard(
                  icon: Icons.delete_forever,
                  title: 'Clear All Data',
                  subtitle: 'Delete all projects and mapping points',
                  onTap: _clearAllData,
                  isLoading: _isLoading,
                  isDangerous: true,
                ),

                if (_statusMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
