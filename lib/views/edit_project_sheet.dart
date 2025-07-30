import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../db/hive_boxes.dart';
import '../models/map_project.dart';
import '../widgets/project_image.dart';
import '../widgets/animated_dialog.dart';

class EditProjectSheet extends StatefulWidget {
  final MapProject project;
  const EditProjectSheet({super.key, required this.project});

  @override
  State<EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends State<EditProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _deleteProject() async {
    final result = await ModernAlertDialog.show<bool>(
      context: context,
      icon: const Icon(
        Icons.delete_forever_outlined,
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
      setState(() => _isLoading = true);
      try {
        // Delete all associated map points
        final pointsBox = HiveBoxes.getMapPointsBox();
        final projectPoints = pointsBox.values
            .where((point) => point.projectId == widget.project.id)
            .toList();

        for (final point in projectPoints) {
          await point.delete();
        }

        // Delete the project image file
        final imageFile = File(widget.project.imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }

        // Delete the project
        await widget.project.delete();

        if (context.mounted) {
          Navigator.pop(context);
          Navigator.pop(context); // Close the details page too
        }
      } catch (e) {
        setState(() => _isLoading = false);
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
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 32,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit Project',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _deleteProject,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  tooltip: 'Delete Project',
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter project name' : null,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: _imageFile == null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            ProjectImage(
                              imagePath: widget.project.imagePath,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 160,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            Container(
                              color: Colors.black.withOpacity(0.3),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit,
                                        size: 32, color: Colors.white),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tap to change image',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 160,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState?.validate() != true) return;
                        setState(() => _isLoading = true);
                        try {
                          String imagePath = widget.project.imagePath;

                          // Handle image update if new image is selected
                          if (_imageFile != null) {
                            // Delete old image
                            final oldImageFile = File(widget.project.imagePath);
                            if (await oldImageFile.exists()) {
                              await oldImageFile.delete();
                            }

                            // Save new image
                            final appDir =
                                await getApplicationDocumentsDirectory();
                            final fileName =
                                'map_${DateTime.now().millisecondsSinceEpoch}${p.extension(_imageFile!.path)}';
                            final savedImage = await _imageFile!
                                .copy(p.join(appDir.path, fileName));
                            imagePath = savedImage.path;
                          }

                          // Update project
                          widget.project.name = _nameController.text.trim();
                          widget.project.imagePath = imagePath;
                          await widget.project.save();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Failed to update project: $e')),
                            );
                          }
                        }
                        setState(() => _isLoading = false);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Project',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
