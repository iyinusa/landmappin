import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../db/hive_boxes.dart';
import '../widgets/animated_project_card.dart';
import '../widgets/animated_empty_state.dart';
import '../widgets/animated_floating_action_button.dart';
import '../widgets/animated_dialog.dart';
import 'add_project_sheet.dart';
import 'project_details_page.dart';
import 'edit_project_sheet.dart';
import 'data_management_page.dart';
import 'google_maps_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});

  final String title;

  void _showProjectContextMenu(BuildContext context, project) {
    AnimatedBottomSheet.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              project.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildAnimatedListTile(
              context,
              Icons.edit_outlined,
              'Edit Project',
              () {
                Navigator.pop(context);
                AnimatedBottomSheet.show(
                  context: context,
                  child: EditProjectSheet(project: project),
                );
              },
            ),
            _buildAnimatedListTile(
              context,
              Icons.delete_outline_rounded,
              'Delete Project',
              () {
                Navigator.pop(context);
                _deleteProject(context, project);
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedListTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ListTile(
              leading: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: onTap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }

  void _deleteProject(BuildContext context, project) async {
    final result = await ModernAlertDialog.show<bool>(
      context: context,
      icon: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.red,
        size: 48,
      ),
      title: const Text('Delete Project'),
      content: const Text(
        'Are you sure you want to delete this project? This action cannot be undone and will also delete all associated map points.',
      ),
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

    if (result == true) {
      try {
        // Delete all associated map points
        final pointsBox = HiveBoxes.getMapPointsBox();
        final projectPoints = pointsBox.values
            .where((point) => point.projectId == project.id)
            .toList();

        for (final point in projectPoints) {
          await point.delete();
        }

        // Delete the project image file
        final imageFile = File(project.imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }

        // Delete the project
        await project.delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete project: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DataManagementPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Map Projects',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: HiveBoxes.getMapProjectsBox().listenable(),
                builder: (context, box, _) {
                  final projects = box.values.toList();
                  if (projects.isEmpty) {
                    return const AnimatedEmptyState();
                  }
                  return GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      return AnimatedProjectCard(
                        project: project,
                        index: index,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      ProjectDetailsPage(project: project),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.1),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut,
                                    )),
                                    child: child,
                                  ),
                                );
                              },
                              transitionDuration:
                                  const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        onLongPress: () {
                          _showProjectContextMenu(context, project);
                        },
                        onMapTap: () {
                          // Check if project has points before navigating to map
                          final box = HiveBoxes.getMapPointsBox();
                          final projectPoints = box.values
                              .where((point) => point.projectId == project.id)
                              .toList();

                          if (projectPoints.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    GoogleMapsView(project: project),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Add some points to the project first to view on map'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedFloatingActionButton(
        onPressed: () {
          AnimatedBottomSheet.show(
            context: context,
            child: const AddProjectSheet(),
          );
        },
        tooltip: 'Add New Project',
      ),
    );
  }
}
