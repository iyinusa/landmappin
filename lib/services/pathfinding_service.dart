import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/navigation_node.dart';
import '../models/navigation_edge.dart';
import '../models/navigation_path.dart';

/// A* pathfinding implementation for custom navigation
class PathfindingService {
  /// Find the shortest path between two nodes using A* algorithm
  NavigationPath? findPath(
    String startNodeId,
    String endNodeId,
    List<NavigationNode> nodes,
    List<NavigationEdge> edges,
  ) {
    debugPrint(
        '[PathfindingService] Finding path from $startNodeId to $endNodeId');
    debugPrint('[PathfindingService] Available nodes: ${nodes.length}');
    debugPrint('[PathfindingService] Available edges: ${edges.length}');

    // Create node map for quick lookup
    final nodeMap = <String, NavigationNode>{};
    for (final node in nodes) {
      nodeMap[node.id] = node;
    }

    debugPrint(
        '[PathfindingService] Node map created with ${nodeMap.length} entries');

    // Validate start and end nodes exist
    if (!nodeMap.containsKey(startNodeId)) {
      debugPrint(
          '[PathfindingService] Error: Start node $startNodeId not found');
      return null;
    }
    if (!nodeMap.containsKey(endNodeId)) {
      debugPrint('[PathfindingService] Error: End node $endNodeId not found');
      return null;
    }

    debugPrint('[PathfindingService] Start and end nodes validated');

    // Build adjacency list
    final adjacencyList = _buildAdjacencyList(edges, nodeMap);

    // Debug adjacency list
    debugPrint('[PathfindingService] Adjacency list built:');
    adjacencyList.forEach((nodeId, neighbors) {
      debugPrint('  Node $nodeId has ${neighbors.length} neighbors');
    });

    // Check if start node has any connections
    if (!adjacencyList.containsKey(startNodeId) ||
        adjacencyList[startNodeId]!.isEmpty) {
      debugPrint(
          '[PathfindingService] Error: Start node $startNodeId has no connections');
      return null;
    }

    // Check if end node has any connections
    if (!adjacencyList.containsKey(endNodeId) ||
        adjacencyList[endNodeId]!.isEmpty) {
      debugPrint(
          '[PathfindingService] Error: End node $endNodeId has no connections');
      return null;
    }

    // Run A* algorithm
    final path = _astar(startNodeId, endNodeId, nodeMap, adjacencyList);

    if (path == null || path.isEmpty) {
      debugPrint('[PathfindingService] No path found between nodes');
      return null;
    }

    debugPrint(
        '[PathfindingService] Path found with ${path.length} nodes: $path');

    // Calculate path details
    final totalDistance = _calculatePathDistance(path, nodeMap, adjacencyList);
    final estimatedTime = _calculateEstimatedTime(totalDistance);
    final instructions = _generateInstructions(path, nodeMap, adjacencyList);

    debugPrint(
        '[PathfindingService] Path details: ${totalDistance}m, ${estimatedTime}s');

    return NavigationPath(
      nodeIds: path,
      totalDistance: totalDistance,
      estimatedTime: estimatedTime,
      instructions: instructions,
    );
  }

  /// Build adjacency list from edges
  Map<String, List<_EdgeInfo>> _buildAdjacencyList(
    List<NavigationEdge> edges,
    Map<String, NavigationNode> nodeMap,
  ) {
    final adjacencyList = <String, List<_EdgeInfo>>{};

    // Initialize adjacency list
    for (final nodeId in nodeMap.keys) {
      adjacencyList[nodeId] = [];
    }

    // Add edges
    for (final edge in edges) {
      if (!edge.isAccessible) continue; // Skip inaccessible edges

      // Add edge from -> to
      adjacencyList[edge.fromNodeId]?.add(
        _EdgeInfo(edge.toNodeId, edge.distance),
      );

      // Add reverse edge if bidirectional
      if (edge.isBidirectional) {
        adjacencyList[edge.toNodeId]?.add(
          _EdgeInfo(edge.fromNodeId, edge.distance),
        );
      }
    }

    return adjacencyList;
  }

  /// A* pathfinding algorithm implementation
  List<String>? _astar(
    String start,
    String goal,
    Map<String, NavigationNode> nodeMap,
    Map<String, List<_EdgeInfo>> adjacencyList,
  ) {
    final openSet =
        PriorityQueue<_AStarNode>((a, b) => a.fScore.compareTo(b.fScore));
    final closedSet = <String>{};
    final gScore = <String, double>{start: 0.0};
    final fScore = <String, double>{
      start: _heuristic(nodeMap[start]!, nodeMap[goal]!)
    };
    final cameFrom = <String, String>{};

    openSet.add(_AStarNode(start, fScore[start]!));

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();

      if (current.nodeId == goal) {
        return _reconstructPath(cameFrom, goal);
      }

      closedSet.add(current.nodeId);

      final neighbors = adjacencyList[current.nodeId] ?? [];
      for (final neighbor in neighbors) {
        if (closedSet.contains(neighbor.nodeId)) continue;

        final tentativeGScore = gScore[current.nodeId]! + neighbor.distance;

        if (!gScore.containsKey(neighbor.nodeId) ||
            tentativeGScore < gScore[neighbor.nodeId]!) {
          cameFrom[neighbor.nodeId] = current.nodeId;
          gScore[neighbor.nodeId] = tentativeGScore;
          fScore[neighbor.nodeId] = tentativeGScore +
              _heuristic(nodeMap[neighbor.nodeId]!, nodeMap[goal]!);

          // Add to open set if not already there
          final existingNode = openSet.toList().cast<_AStarNode?>().firstWhere(
                (node) => node?.nodeId == neighbor.nodeId,
                orElse: () => null,
              );

          if (existingNode == null) {
            openSet.add(_AStarNode(neighbor.nodeId, fScore[neighbor.nodeId]!));
          }
        }
      }
    }

    return null; // No path found
  }

  /// Heuristic function for A* (Euclidean distance)
  double _heuristic(NavigationNode a, NavigationNode b) {
    final dx = a.lat - b.lat;
    final dy = a.lng - b.lng;
    return sqrt(dx * dx + dy * dy) * 111320; // Approximate meters per degree
  }

  /// Reconstruct path from came_from map
  List<String> _reconstructPath(Map<String, String> cameFrom, String current) {
    final path = <String>[current];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.insert(0, current);
    }
    return path;
  }

  /// Calculate total distance of path
  double _calculatePathDistance(
    List<String> path,
    Map<String, NavigationNode> nodeMap,
    Map<String, List<_EdgeInfo>> adjacencyList,
  ) {
    double totalDistance = 0.0;

    for (int i = 0; i < path.length - 1; i++) {
      final currentNodeId = path[i];
      final nextNodeId = path[i + 1];

      final neighbors = adjacencyList[currentNodeId] ?? [];
      final edge = neighbors.firstWhere(
        (neighbor) => neighbor.nodeId == nextNodeId,
        orElse: () => _EdgeInfo(nextNodeId, 0),
      );

      totalDistance += edge.distance;
    }

    return totalDistance;
  }

  /// Calculate estimated time (assuming walking speed of 1.4 m/s)
  double _calculateEstimatedTime(double distanceInMeters) {
    const walkingSpeedMps = 1.4; // meters per second
    return (distanceInMeters / walkingSpeedMps) / 60; // Convert to minutes
  }

  /// Generate turn-by-turn instructions
  List<NavigationInstruction> _generateInstructions(
    List<String> path,
    Map<String, NavigationNode> nodeMap,
    Map<String, List<_EdgeInfo>> adjacencyList,
  ) {
    final instructions = <NavigationInstruction>[];
    double distanceFromStart = 0.0;

    for (int i = 0; i < path.length; i++) {
      final nodeId = path[i];
      final node = nodeMap[nodeId]!;

      NavigationDirection direction;
      String instruction;

      if (i == 0) {
        direction = NavigationDirection.start;
        instruction = 'Start at ${node.label}';
      } else if (i == path.length - 1) {
        direction = NavigationDirection.arrive;
        instruction = 'Arrive at ${node.label}';
      } else {
        // Calculate direction based on previous and next nodes
        direction = _calculateDirection(
          nodeMap[path[i - 1]]!,
          node,
          nodeMap[path[i + 1]]!,
        );
        instruction = _getDirectionInstruction(direction, node.label);
      }

      instructions.add(NavigationInstruction(
        nodeId: nodeId,
        instruction: instruction,
        distanceFromStart: distanceFromStart,
        direction: direction,
      ));

      // Update distance for next instruction
      if (i < path.length - 1) {
        final nextNodeId = path[i + 1];
        final neighbors = adjacencyList[nodeId] ?? [];
        final edge = neighbors.firstWhere(
          (neighbor) => neighbor.nodeId == nextNodeId,
          orElse: () => _EdgeInfo(nextNodeId, 0),
        );
        distanceFromStart += edge.distance;
      }
    }

    return instructions;
  }

  /// Calculate direction based on three consecutive nodes
  NavigationDirection _calculateDirection(
    NavigationNode previous,
    NavigationNode current,
    NavigationNode next,
  ) {
    // Calculate vectors
    final vector1 = [current.lat - previous.lat, current.lng - previous.lng];
    final vector2 = [next.lat - current.lat, next.lng - current.lng];

    // Calculate angle between vectors
    final dot = vector1[0] * vector2[0] + vector1[1] * vector2[1];
    final det = vector1[0] * vector2[1] - vector1[1] * vector2[0];
    final angle = atan2(det, dot) * (180 / pi);

    // Determine direction based on angle
    if (angle.abs() < 15) {
      return NavigationDirection.straight;
    } else if (angle > 15 && angle <= 45) {
      return NavigationDirection.turnSlightLeft;
    } else if (angle > 45 && angle <= 135) {
      return NavigationDirection.turnLeft;
    } else if (angle > 135) {
      return NavigationDirection.turnSharpLeft;
    } else if (angle < -15 && angle >= -45) {
      return NavigationDirection.turnSlightRight;
    } else if (angle < -45 && angle >= -135) {
      return NavigationDirection.turnRight;
    } else {
      return NavigationDirection.turnSharpRight;
    }
  }

  /// Get instruction text for direction
  String _getDirectionInstruction(
      NavigationDirection direction, String locationName) {
    switch (direction) {
      case NavigationDirection.straight:
        return 'Continue straight to $locationName';
      case NavigationDirection.turnLeft:
        return 'Turn left at $locationName';
      case NavigationDirection.turnRight:
        return 'Turn right at $locationName';
      case NavigationDirection.turnSlightLeft:
        return 'Turn slight left to $locationName';
      case NavigationDirection.turnSlightRight:
        return 'Turn slight right to $locationName';
      case NavigationDirection.turnSharpLeft:
        return 'Turn sharp left at $locationName';
      case NavigationDirection.turnSharpRight:
        return 'Turn sharp right at $locationName';
      case NavigationDirection.uturn:
        return 'Make U-turn at $locationName';
      default:
        return 'Proceed to $locationName';
    }
  }
}

/// Helper class for A* algorithm
class _AStarNode {
  final String nodeId;
  final double fScore;

  _AStarNode(this.nodeId, this.fScore);
}

/// Helper class for edge information
class _EdgeInfo {
  final String nodeId;
  final double distance;

  _EdgeInfo(this.nodeId, this.distance);
}

/// Simple priority queue implementation
class PriorityQueue<T> {
  final List<T> _items = [];
  final Comparator<T> _compare;

  PriorityQueue(this._compare);

  void add(T item) {
    _items.add(item);
    _items.sort(_compare);
  }

  T removeFirst() {
    return _items.removeAt(0);
  }

  bool get isNotEmpty => _items.isNotEmpty;
  List<T> toList() => List<T>.from(_items);
}
