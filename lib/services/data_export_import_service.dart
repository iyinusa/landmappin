import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/map_project.dart';
import '../models/map_point.dart';
import '../db/hive_boxes.dart';

class DataExportImportService {
  static const String exportFileName = 'map_projects_export.json';

  /// Export all Hive data to JSON file
  static Future<File> exportData() async {
    final projectsBox = HiveBoxes.getMapProjectsBox();
    final pointsBox = HiveBoxes.getMapPointsBox();

    final exportData = {
      'projects': projectsBox.values
          .map((project) => {
                'id': project.id,
                'name': project.name,
                'imagePath': project.imagePath,
              })
          .toList(),
      'points': pointsBox.values
          .map((point) => {
                'label': point.label,
                'dx': point.dx,
                'dy': point.dy,
                'lat': point.lat,
                'lng': point.lng,
                'projectId': point.projectId,
              })
          .toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, exportFileName));

    await file.writeAsString(jsonString);
    return file;
  }

  /// Import data from JSON file
  static Future<ImportResult> importData(File jsonFile) async {
    try {
      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate data structure
      if (!data.containsKey('projects') || !data.containsKey('points')) {
        return ImportResult(
          success: false,
          message: 'Invalid data format. Missing projects or points data.',
        );
      }

      final projectsBox = HiveBoxes.getMapProjectsBox();
      final pointsBox = HiveBoxes.getMapPointsBox();

      int projectsImported = 0;
      int pointsImported = 0;

      // Import projects
      final projects = data['projects'] as List<dynamic>;
      for (final projectData in projects) {
        final project = MapProject(
          id: projectData['id'] as String,
          name: projectData['name'] as String,
          imagePath: projectData['imagePath'] as String,
        );

        // Check if project already exists
        final existingProject =
            projectsBox.values.where((p) => p.id == project.id).firstOrNull;

        if (existingProject == null) {
          await projectsBox.add(project);
          projectsImported++;
        }
      }

      // Import points
      final points = data['points'] as List<dynamic>;
      for (final pointData in points) {
        final point = MapPoint(
          label: pointData['label'] as String,
          dx: (pointData['dx'] as num).toDouble(),
          dy: (pointData['dy'] as num).toDouble(),
          lat: (pointData['lat'] as num).toDouble(),
          lng: (pointData['lng'] as num).toDouble(),
          projectId: pointData['projectId'] as String,
        );

        // Check if point already exists (same label and project)
        final existingPoint = pointsBox.values
            .where(
                (p) => p.label == point.label && p.projectId == point.projectId)
            .firstOrNull;

        if (existingPoint == null) {
          await pointsBox.add(point);
          pointsImported++;
        }
      }

      return ImportResult(
        success: true,
        message:
            'Successfully imported $projectsImported projects and $pointsImported points.',
        projectsImported: projectsImported,
        pointsImported: pointsImported,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Error importing data: ${e.toString()}',
      );
    }
  }

  /// Create demo data
  static Future<ImportResult> importDemoData() async {
    try {
      // Load demo data from assets
      final demoJson =
          await rootBundle.loadString('assets/demo/demo_data.json');
      final demoData = jsonDecode(demoJson) as Map<String, dynamic>;

      final projectsBox = HiveBoxes.getMapProjectsBox();
      final pointsBox = HiveBoxes.getMapPointsBox();

      int projectsImported = 0;
      int pointsImported = 0;

      // Get app directory for storing images
      final appDir = await getApplicationDocumentsDirectory();

      // Import projects
      final projects = demoData['projects'] as List<dynamic>;
      for (final projectData in projects) {
        // Check if project already exists
        final existingProject = projectsBox.values
            .where((p) => p.id == projectData['id'] as String)
            .firstOrNull;

        if (existingProject == null) {
          String imagePath = projectData['imagePath'] as String;

          // Copy asset image to app directory
          if (imagePath.startsWith('assets/')) {
            try {
              // Load asset as bytes
              final assetBytes = await rootBundle.load(imagePath);
              final bytes = assetBytes.buffer.asUint8List();

              // Create file name from asset path
              final fileName =
                  'demo_${projectData['id']}_${p.basename(imagePath)}';
              final imageFile = File(p.join(appDir.path, fileName));

              // Write bytes to file
              await imageFile.writeAsBytes(bytes);
              imagePath = imageFile.path;
            } catch (e) {
              // If asset loading fails, keep original path (will show error in UI)
              print('Failed to load asset $imagePath: $e');
            }
          }

          final project = MapProject(
            id: projectData['id'] as String,
            name: projectData['name'] as String,
            imagePath: imagePath,
          );

          await projectsBox.add(project);
          projectsImported++;
        }
      }

      // Import points
      final points = demoData['points'] as List<dynamic>;
      for (final pointData in points) {
        final point = MapPoint(
          label: pointData['label'] as String,
          dx: (pointData['dx'] as num).toDouble(),
          dy: (pointData['dy'] as num).toDouble(),
          lat: (pointData['lat'] as num).toDouble(),
          lng: (pointData['lng'] as num).toDouble(),
          projectId: pointData['projectId'] as String,
        );

        // Check if point already exists (same label and project)
        final existingPoint = pointsBox.values
            .where(
                (p) => p.label == point.label && p.projectId == point.projectId)
            .firstOrNull;

        if (existingPoint == null) {
          await pointsBox.add(point);
          pointsImported++;
        }
      }

      return ImportResult(
        success: true,
        message:
            'Successfully imported $projectsImported projects and $pointsImported points.',
        projectsImported: projectsImported,
        pointsImported: pointsImported,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Error importing demo data: ${e.toString()}',
      );
    }
  }

  /// Get the default export file path
  static Future<String> getExportFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, exportFileName);
  }

  /// Check if export file exists
  static Future<bool> exportFileExists() async {
    final filePath = await getExportFilePath();
    return File(filePath).exists();
  }

  /// Clear all data
  static Future<void> clearAllData() async {
    final projectsBox = HiveBoxes.getMapProjectsBox();
    final pointsBox = HiveBoxes.getMapPointsBox();

    await projectsBox.clear();
    await pointsBox.clear();
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int projectsImported;
  final int pointsImported;

  ImportResult({
    required this.success,
    required this.message,
    this.projectsImported = 0,
    this.pointsImported = 0,
  });
}
