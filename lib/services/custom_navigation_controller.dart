import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/navigation_node.dart';
import '../models/navigation_edge.dart';
import '../models/navigation_path.dart';
import '../models/map_point.dart';
import '../services/pathfinding_service.dart';
import '../services/location_service.dart';
import '../db/hive_boxes.dart';

/// Custom navigation state enum
enum CustomNavigationState {
  idle,
  calculating,
  navigating,
  finished,
  error,
}

/// Navigation result class for detailed error handling
class NavigationResult {
  final bool success;
  final String? error;
  final String? errorCode;

  NavigationResult.success()
      : success = true,
        error = null,
        errorCode = null;

  NavigationResult.failure(this.error, this.errorCode) : success = false;
}

/// Custom Navigation Controller for overlay-based navigation
class CustomNavigationController extends ChangeNotifier {
  // Navigation state
  CustomNavigationState _state = CustomNavigationState.idle;
  CustomNavigationState get state => _state;

  // Current location
  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  // Navigation path
  NavigationPath? _currentPath;
  NavigationPath? get currentPath => _currentPath;

  // Current navigation step
  int _currentStepIndex = 0;
  int get currentStepIndex => _currentStepIndex;
  NavigationInstruction? get currentInstruction => _currentPath != null &&
          _currentStepIndex < _currentPath!.instructions.length
      ? _currentPath!.instructions[_currentStepIndex]
      : null;

  // Distance to next waypoint
  double _distanceToNext = 0;
  double get distanceToNext => _distanceToNext;

  // Services
  final PathfindingService _pathfindingService = PathfindingService();
  final LocationService _locationService = LocationService();

  // Location tracking state
  bool _isTracking = false;

  /// Start custom navigation to destination
  Future<bool> startNavigation(
    String destinationNodeId,
    String projectId,
  ) async {
    try {
      _setState(CustomNavigationState.calculating);
      debugPrint(
          '[CustomNavigation] Starting navigation to node: $destinationNodeId');

      // Get current location
      await _updateCurrentLocation();

      if (_currentLocation == null) {
        debugPrint('[CustomNavigation] Error: Could not get current location');
        _setState(CustomNavigationState.error);
        return false;
      }

      debugPrint(
          '[CustomNavigation] Current location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');

      // Get navigation nodes and edges for this project
      final nodes = await getNavigationNodes(projectId);
      final edges = await _getNavigationEdges(projectId);

      debugPrint(
          '[CustomNavigation] Found ${nodes.length} nodes and ${edges.length} edges');

      if (nodes.isEmpty) {
        debugPrint(
            '[CustomNavigation] Error: No navigation nodes found for project');
        _setState(CustomNavigationState.error);
        return false;
      }

      // Find nearest node to current location as starting point
      final nearestStartNode =
          await _findNearestNode(_currentLocation!, projectId);
      if (nearestStartNode == null) {
        debugPrint(
            '[CustomNavigation] Error: Could not find nearest start node');
        _setState(CustomNavigationState.error);
        return false;
      }

      debugPrint(
          '[CustomNavigation] Start node: ${nearestStartNode.id} (${nearestStartNode.label})');

      // Verify destination node exists
      final destinationNode = nodes.firstWhere(
        (node) => node.id == destinationNodeId,
        orElse: () => NavigationNode(
            id: '', label: '', lat: 0, lng: 0, dx: 0, dy: 0, projectId: ''),
      );

      if (destinationNode.id.isEmpty) {
        debugPrint(
            '[CustomNavigation] Error: Destination node not found: $destinationNodeId');
        _setState(CustomNavigationState.error);
        return false;
      }

      debugPrint(
          '[CustomNavigation] Destination node: ${destinationNode.id} (${destinationNode.label})');

      // Calculate path using A* algorithm
      final path = _pathfindingService.findPath(
        nearestStartNode.id,
        destinationNodeId,
        nodes,
        edges,
      );

      if (path == null) {
        debugPrint('[CustomNavigation] Error: No path found between nodes');
        _setState(CustomNavigationState.error);
        return false;
      }

      debugPrint(
          '[CustomNavigation] Path found with ${path.nodeIds.length} nodes');
      _currentPath = path;
      _currentStepIndex = 0;

      // Start location tracking
      await _startLocationTracking();

      _setState(CustomNavigationState.navigating);
      debugPrint('[CustomNavigation] Navigation started successfully');
      return true;
    } catch (e) {
      debugPrint('[CustomNavigation] Error starting navigation: $e');
      _setState(CustomNavigationState.error);
      return false;
    }
  }

  /// Enhanced navigation start with detailed error reporting
  Future<NavigationResult> startNavigationWithResult(
    String destinationNodeId,
    String projectId,
  ) async {
    try {
      _setState(CustomNavigationState.calculating);
      debugPrint(
          '[CustomNavigation] Starting navigation to node: $destinationNodeId');

      // Get current location
      await _updateCurrentLocation();

      if (_currentLocation == null) {
        debugPrint('[CustomNavigation] Error: Could not get current location');
        _setState(CustomNavigationState.error);
        return NavigationResult.failure(
          'Unable to determine your current location. Please ensure GPS is enabled.',
          'NO_LOCATION',
        );
      }

      debugPrint(
          '[CustomNavigation] Current location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');

      // Get navigation nodes and edges for this project
      final nodes = await getNavigationNodes(projectId);
      final edges = await _getNavigationEdges(projectId);

      debugPrint(
          '[CustomNavigation] Found ${nodes.length} nodes and ${edges.length} edges');

      if (nodes.isEmpty) {
        debugPrint(
            '[CustomNavigation] Error: No navigation nodes found for project');
        _setState(CustomNavigationState.error);
        return NavigationResult.failure(
          'No navigation points found for this map. Please add location markers first.',
          'NO_NODES',
        );
      }

      // Find nearest node to current location as starting point
      final nearestStartNode =
          await _findNearestNode(_currentLocation!, projectId);
      if (nearestStartNode == null) {
        debugPrint(
            '[CustomNavigation] Error: Could not find nearest start node');
        _setState(CustomNavigationState.error);
        return NavigationResult.failure(
          'Cannot find a navigation point near your current location.',
          'NO_START_NODE',
        );
      }

      debugPrint(
          '[CustomNavigation] Start node: ${nearestStartNode.id} (${nearestStartNode.label})');

      // Verify destination node exists with enhanced debugging
      debugPrint(
          '[CustomNavigation] Looking for destination node with ID: $destinationNodeId');
      debugPrint(
          '[CustomNavigation] Available node IDs: ${nodes.map((n) => n.id).toList()}');

      NavigationNode? destinationNode;
      for (final node in nodes) {
        if (node.id == destinationNodeId) {
          destinationNode = node;
          break;
        }
      }

      if (destinationNode == null) {
        debugPrint(
            '[CustomNavigation] Error: Destination node not found: $destinationNodeId');
        debugPrint('[CustomNavigation] Available nodes:');
        for (final node in nodes) {
          debugPrint(
              '  - ${node.id}: ${node.label} (${node.lat}, ${node.lng})');
        }
        _setState(CustomNavigationState.error);
        return NavigationResult.failure(
          'The selected destination is not accessible through the navigation network. Node ID: $destinationNodeId',
          'NO_DESTINATION_NODE',
        );
      }

      debugPrint(
          '[CustomNavigation] Destination node: ${destinationNode.id} (${destinationNode.label})');

      // Calculate path using A* algorithm
      final path = _pathfindingService.findPath(
        nearestStartNode.id,
        destinationNode.id,
        nodes,
        edges,
      );

      if (path == null) {
        debugPrint('[CustomNavigation] Error: No path found between nodes');
        _setState(CustomNavigationState.error);
        return NavigationResult.failure(
          'No route found between your location and the destination. The points may not be connected.',
          'NO_PATH',
        );
      }

      debugPrint(
          '[CustomNavigation] Path found with ${path.nodeIds.length} nodes');
      _currentPath = path;
      _currentStepIndex = 0;

      // Start location tracking
      final trackingStarted = await _startLocationTracking();
      if (!trackingStarted) {
        debugPrint(
            '[CustomNavigation] Error: Could not start location tracking');
        _setState(CustomNavigationState.error);
        return NavigationResult.failure(
          'Unable to start location tracking for navigation. Please check your device settings.',
          'LOCATION_TRACKING_FAILED',
        );
      }

      _setState(CustomNavigationState.navigating);
      debugPrint('[CustomNavigation] Navigation started successfully');
      return NavigationResult.success();
    } catch (e) {
      debugPrint('[CustomNavigation] Error starting navigation: $e');
      _setState(CustomNavigationState.error);
      return NavigationResult.failure(
        'An unexpected error occurred: ${e.toString()}',
        'UNKNOWN_ERROR',
      );
    }
  }

  /// Stop navigation
  void stopNavigation() {
    _stopLocationTracking();
    _currentPath = null;
    _currentStepIndex = 0;
    _distanceToNext = 0;
    _setState(CustomNavigationState.idle);
  }

  /// Get polyline points for current navigation path
  List<LatLng> getNavigationPolylinePoints() {
    if (_currentPath == null || _currentLocation == null) return [];

    // Create polyline that includes current location as starting point
    final pathPoints = _getPolylineFromNodeIds(_currentPath!.nodeIds);

    // If we have a current location and path points, create a complete route
    if (pathPoints.isNotEmpty) {
      // Add current location as the first point
      return [_currentLocation!, ...pathPoints];
    }

    return pathPoints;
  }

  /// Update current location manually
  Future<void> _updateCurrentLocation() async {
    try {
      // Use LocationService for consistent location handling
      await _locationService.initialize();
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  /// Start location tracking
  Future<bool> _startLocationTracking() async {
    if (_isTracking) return true;

    try {
      // Use optimized LocationService for better real-time tracking
      await _locationService.initialize();

      bool success = await _locationService.startTracking(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1.0, // Update every 1 meter for navigation
        timeInterval: const Duration(milliseconds: 500), // 500ms updates
      );

      if (success) {
        // Subscribe to location updates
        _locationService.addLocationUpdateCallback((position) {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateNavigationProgress();
          notifyListeners();
        });

        _isTracking = true;
        debugPrint('✅ Custom navigation location tracking started');
        return true;
      } else {
        debugPrint('❌ Failed to start custom navigation location tracking');
        return false;
      }
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void _stopLocationTracking() {
    if (_isTracking) {
      _locationService.stopTracking();
      _isTracking = false;
      debugPrint('🛑 Custom navigation location tracking stopped');
    }
  }

  /// Update navigation progress based on current location
  void _updateNavigationProgress() {
    if (_currentPath == null || _currentLocation == null) return;

    final nodes = _getNodeMapFromPath(_currentPath!.nodeIds);

    // Check if we've reached the next waypoint
    if (_currentStepIndex < _currentPath!.instructions.length - 1) {
      final currentInstruction = _currentPath!.instructions[_currentStepIndex];
      final currentNode = nodes[currentInstruction.nodeId];

      if (currentNode != null) {
        final distanceToCurrentNode = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          currentNode.lat,
          currentNode.lng,
        );

        // If we're within 10 meters of the waypoint, advance to next step
        if (distanceToCurrentNode < 10.0) {
          _currentStepIndex++;

          // Check if navigation is complete
          if (_currentStepIndex >= _currentPath!.instructions.length - 1) {
            _setState(CustomNavigationState.finished);
            stopNavigation();
            return;
          }
        }

        _distanceToNext = distanceToCurrentNode;
      }
    }
  }

  /// Find nearest navigation node to given location
  Future<NavigationNode?> _findNearestNode(
      LatLng location, String projectId) async {
    final nodes = await getNavigationNodes(projectId);
    if (nodes.isEmpty) return null;

    NavigationNode? nearestNode;
    double minDistance = double.infinity;

    for (final node in nodes) {
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        node.lat,
        node.lng,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestNode = node;
      }
    }

    return nearestNode;
  }

  /// Get navigation nodes for project
  Future<List<NavigationNode>> getNavigationNodes(String projectId) async {
    try {
      debugPrint(
          '[CustomNavigation] Getting navigation nodes for project: $projectId');

      // For now, we'll create navigation nodes from map points
      // In the future, this should come from a dedicated navigation nodes box
      final mapPointsBox = HiveBoxes.getMapPointsBox();
      final mapPoints = mapPointsBox.values
          .where((point) => point.projectId == projectId)
          .toList();

      debugPrint(
          '[CustomNavigation] Found ${mapPoints.length} map points to convert to nodes');

      final nodes = <NavigationNode>[];
      int nodeCounter = 0;

      for (final point in mapPoints) {
        // Skip corner points and bounds that shouldn't be navigation nodes
        final name = point.label.toLowerCase();
        if (name.contains('sw corner') ||
            name.contains('ne corner') ||
            name.contains('bound')) {
          continue;
        }

        // Create a robust node ID - use the point's key if available, otherwise generate one
        String nodeId;
        if (point.key != null) {
          nodeId = point.key.toString();
        } else {
          // Generate a unique ID based on label and coordinates
          nodeId =
              'node_${point.label.replaceAll(' ', '_')}_${point.lat.toStringAsFixed(6)}_${point.lng.toStringAsFixed(6)}';
        }

        final node = NavigationNode(
          id: nodeId,
          label: point.label,
          lat: point.lat,
          lng: point.lng,
          dx: point.dx,
          dy: point.dy,
          projectId: point.projectId,
        );

        nodes.add(node);
        nodeCounter++;

        debugPrint(
            '[CustomNavigation] Created node $nodeCounter: ${node.id} (${node.label}) at ${node.lat}, ${node.lng}');
      }

      debugPrint('[CustomNavigation] Created ${nodes.length} navigation nodes');

      // Debug: Print all node IDs for troubleshooting
      for (final node in nodes) {
        debugPrint(
            '[CustomNavigation] Node available: ${node.id} -> ${node.label}');
      }

      return nodes;
    } catch (e) {
      debugPrint('[CustomNavigation] Error getting navigation nodes: $e');
      return [];
    }
  }

  /// Get navigation edges for project
  Future<List<NavigationEdge>> _getNavigationEdges(String projectId) async {
    try {
      debugPrint(
          '[CustomNavigation] Getting navigation edges for project: $projectId');

      // For now, we'll create a basic connectivity between nearby nodes
      // In the future, this should come from a dedicated navigation edges box
      final nodes = await getNavigationNodes(projectId);
      final edges = <NavigationEdge>[];

      debugPrint(
          '[CustomNavigation] Creating edges between ${nodes.length} nodes');

      // Create edges between nodes that are close to each other (within 100 meters)
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final node1 = nodes[i];
          final node2 = nodes[j];

          final distance = Geolocator.distanceBetween(
            node1.lat,
            node1.lng,
            node2.lat,
            node2.lng,
          );

          // Connect nodes that are within 100 meters of each other
          if (distance <= 100.0) {
            // Create bidirectional edges
            edges.add(NavigationEdge(
              id: '${node1.id}_${node2.id}',
              fromNodeId: node1.id,
              toNodeId: node2.id,
              distance: distance,
              projectId: projectId,
              isBidirectional: true,
              isAccessible: true,
            ));

            edges.add(NavigationEdge(
              id: '${node2.id}_${node1.id}',
              fromNodeId: node2.id,
              toNodeId: node1.id,
              distance: distance,
              projectId: projectId,
              isBidirectional: true,
              isAccessible: true,
            ));

            debugPrint(
                '[CustomNavigation] Created bidirectional edge between ${node1.label} and ${node2.label} (${distance.toStringAsFixed(1)}m)');
          }
        }
      }

      debugPrint('[CustomNavigation] Created ${edges.length} navigation edges');
      return edges;
    } catch (e) {
      debugPrint('[CustomNavigation] Error getting navigation edges: $e');
      return [];
    }
  }

  /// Get polyline points from node IDs
  List<LatLng> _getPolylineFromNodeIds(List<String> nodeIds) {
    final points = <LatLng>[];

    try {
      final mapPointsBox = HiveBoxes.getMapPointsBox();

      for (final nodeId in nodeIds) {
        // Try to find the corresponding map point
        MapPoint? foundPoint;

        // First try to find by key (if nodeId is numeric)
        final numericKey = int.tryParse(nodeId);
        if (numericKey != null) {
          foundPoint = mapPointsBox.get(numericKey);
        }

        // If not found by key, search through all points
        if (foundPoint == null) {
          for (final point in mapPointsBox.values) {
            // Check if the nodeId matches the point's key or a generated nodeId pattern
            if (point.key.toString() == nodeId ||
                nodeId.contains(point.label.replaceAll(' ', '_')) ||
                nodeId ==
                    'node_${point.label.replaceAll(' ', '_')}_${point.lat.toStringAsFixed(6)}_${point.lng.toStringAsFixed(6)}') {
              foundPoint = point;
              break;
            }
          }
        }

        if (foundPoint != null) {
          points.add(LatLng(foundPoint.lat, foundPoint.lng));
          debugPrint(
              '[CustomNavigation] Found polyline point for node $nodeId: ${foundPoint.lat}, ${foundPoint.lng}');
        } else {
          debugPrint(
              '[CustomNavigation] Warning: Could not find point for node ID: $nodeId');
        }
      }

      debugPrint(
          '[CustomNavigation] Generated polyline with ${points.length} points from ${nodeIds.length} node IDs');
    } catch (e) {
      debugPrint(
          '[CustomNavigation] Error generating polyline from node IDs: $e');
    }

    return points;
  }

  /// Get node map from path node IDs
  Map<String, NavigationNode> _getNodeMapFromPath(List<String> nodeIds) {
    final nodeMap = <String, NavigationNode>{};
    final mapPointsBox = HiveBoxes.getMapPointsBox();

    for (final nodeId in nodeIds) {
      final point = mapPointsBox.get(int.tryParse(nodeId));
      if (point != null) {
        nodeMap[nodeId] = NavigationNode(
          id: nodeId,
          label: point.label,
          lat: point.lat,
          lng: point.lng,
          dx: point.dx,
          dy: point.dy,
          projectId: point.projectId,
        );
      }
    }

    return nodeMap;
  }

  /// Set navigation state and notify listeners
  void _setState(CustomNavigationState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Get remaining distance in current path
  String get remainingDistance {
    if (_currentPath == null ||
        _currentStepIndex >= _currentPath!.instructions.length) {
      return '0 m';
    }

    final remainingDist = _currentPath!.totalDistance -
        (_currentStepIndex > 0
            ? _currentPath!.instructions[_currentStepIndex].distanceFromStart
            : 0);

    if (remainingDist >= 1000) {
      return '${(remainingDist / 1000).toStringAsFixed(1)} km';
    }
    return '${remainingDist.toStringAsFixed(0)} m';
  }

  /// Get remaining time in current path
  String get remainingTime {
    if (_currentPath == null) return '0 min';

    final remainingMinutes = _currentPath!.estimatedTime *
        (1 -
            (_currentStepIndex / _currentPath!.instructions.length.toDouble()));

    if (remainingMinutes >= 60) {
      final hours = (remainingMinutes / 60).floor();
      final minutes = (remainingMinutes % 60).round();
      return '${hours}h ${minutes}min';
    }
    return '${remainingMinutes.round()} min';
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }
}
