import 'package:flutter/material.dart';
import '../models/map_project.dart';
import '../models/map_point.dart';
import '../db/hive_boxes.dart';
import '../widgets/project_image.dart';
import '../widgets/animated_dialog.dart';
import 'edit_project_sheet.dart';
import 'google_maps_view.dart';

class ProjectDetailsPage extends StatelessWidget {
  final MapProject project;
  const ProjectDetailsPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Hero(
          tag: 'project_title_${project.id}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              project.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoogleMapsView(project: project),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined),
              tooltip: 'View on Map',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                AnimatedBottomSheet.show(
                  context: context,
                  child: EditProjectSheet(project: project),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Project',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[50]!,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: MappingTool(project: project),
        ),
      ),
    );
  }
}

class MappingTool extends StatefulWidget {
  final MapProject project;
  const MappingTool({required this.project, super.key});

  @override
  State<MappingTool> createState() => _MappingToolState();
}

class _MappingToolState extends State<MappingTool> {
  final List<MapPoint> _points = [];

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  void _loadPoints() {
    final box = HiveBoxes.getMapPointsBox();
    final projectPoints = box.values
        .where((point) => point.projectId == widget.project.id)
        .toList();
    setState(() {
      _points.clear();
      _points.addAll(projectPoints);
    });

    // output all _points
    debugPrint(
        'Loaded ${_points.length} points for project ${widget.project.id}');
    for (var point in _points) {
      debugPrint(
          'label: ${point.label}, dx: ${point.dx}, dy: ${point.dy}, lat: ${point.lat}, lng: ${point.lng}, projectId: ${point.projectId}');
    }
  }

  void _addPoint(TapUpDetails details, BuildContext context) async {
    final labelController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final result = await ModernAlertDialog.show<MapPoint>(
      context: context,
      icon: const Icon(
        Icons.add_location_outlined,
        color: Colors.green,
        size: 48,
      ),
      title: const Text('Add Point'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: latController,
            decoration: const InputDecoration(
              labelText: 'Latitude',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lngController,
            decoration: const InputDecoration(
              labelText: 'Longitude',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        ModernDialogButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        ModernDialogButton(
          text: 'Add',
          isPrimary: true,
          onPressed: () {
            if (labelController.text.isNotEmpty &&
                latController.text.isNotEmpty &&
                lngController.text.isNotEmpty) {
              Navigator.pop(
                context,
                MapPoint(
                  label: labelController.text,
                  dx: details.localPosition.dx,
                  dy: details.localPosition.dy,
                  lat: double.tryParse(latController.text) ?? 0,
                  lng: double.tryParse(lngController.text) ?? 0,
                  projectId: widget.project.id,
                ),
              );
            }
          },
        ),
      ],
    );
    if (result != null) {
      final box = HiveBoxes.getMapPointsBox();
      box.add(result);
      setState(() {
        _points.add(result);
      });
    }
  }

  void _editPoint(MapPoint point, BuildContext context) async {
    final labelController = TextEditingController(text: point.label);
    final latController = TextEditingController(text: point.lat.toString());
    final lngController = TextEditingController(text: point.lng.toString());

    final result = await ModernAlertDialog.show<MapPoint>(
      context: context,
      icon: const Icon(
        Icons.edit_location_outlined,
        color: Colors.blue,
        size: 48,
      ),
      title: const Text('Edit Point'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: latController,
            decoration: const InputDecoration(
              labelText: 'Latitude',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lngController,
            decoration: const InputDecoration(
              labelText: 'Longitude',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        ModernDialogButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        ModernDialogButton(
          text: 'Delete',
          isDestructive: true,
          onPressed: () async {
            // Delete the point
            await point.delete();
            setState(() {
              _points.remove(point);
            });
            if (context.mounted) Navigator.pop(context);
          },
        ),
        ModernDialogButton(
          text: 'Save',
          isPrimary: true,
          onPressed: () {
            if (labelController.text.isNotEmpty &&
                latController.text.isNotEmpty &&
                lngController.text.isNotEmpty) {
              Navigator.pop(
                context,
                MapPoint(
                  label: labelController.text,
                  dx: point.dx,
                  dy: point.dy,
                  lat: double.tryParse(latController.text) ?? 0,
                  lng: double.tryParse(lngController.text) ?? 0,
                  projectId: widget.project.id,
                ),
              );
            }
          },
        ),
      ],
    );

    if (result != null) {
      final box = HiveBoxes.getMapPointsBox();
      // Update the existing point
      final index = _points.indexOf(point);
      if (index != -1) {
        await point.delete();
        await box.add(result);
        setState(() {
          _points[index] = result;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade300,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: GestureDetector(
                onTapUp: (details) => _addPoint(details, context),
                child: Stack(
                  children: [
                    ProjectImage(
                      imagePath: widget.project.imagePath,
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                    ..._points.map((point) => Positioned(
                          left: point.dx - 12,
                          top: point.dy - 12,
                          child: GestureDetector(
                            onTap: () => _editPoint(point, context),
                            child: Tooltip(
                              message: point.label,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _points.isNotEmpty
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GoogleMapsView(project: widget.project),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.map),
            label: const Text('View on Google Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap on image to add points • Tap on markers to edit • Pinch to zoom',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Points:', style: Theme.of(context).textTheme.titleMedium),
        Expanded(
          child: ListView.builder(
            itemCount: _points.length,
            itemBuilder: (context, index) {
              final point = _points[index];
              return GestureDetector(
                onTap: () => _editPoint(point, context),
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.red),
                  title: Text(point.label),
                  subtitle: Text('Lat: ${point.lat}, Lng: ${point.lng}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
