import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/navigation_node.dart';
import '../models/navigation_edge.dart';
import '../models/map_project.dart';

/// Widget for drawing navigation paths on the overlay image
class PathDrawingWidget extends StatefulWidget {
  final MapProject project;
  final List<NavigationNode> existingNodes;
  final List<NavigationEdge> existingEdges;
  final LatLngBounds? imageBounds;
  final Function(NavigationNode) onNodeAdded;
  final Function(NavigationEdge) onEdgeAdded;
  final Function(NavigationNode) onNodeRemoved;
  final Function(NavigationEdge) onEdgeRemoved;

  const PathDrawingWidget({
    super.key,
    required this.project,
    required this.existingNodes,
    required this.existingEdges,
    required this.imageBounds,
    required this.onNodeAdded,
    required this.onEdgeAdded,
    required this.onNodeRemoved,
    required this.onEdgeRemoved,
  });

  @override
  State<PathDrawingWidget> createState() => _PathDrawingWidgetState();
}

class _PathDrawingWidgetState extends State<PathDrawingWidget> {
  PathDrawingMode _currentMode = PathDrawingMode.viewOnly;
  NavigationNode? _connectingFromNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildModeSelector(),
        const SizedBox(height: 10),
        _buildInstructions(),
        if (_currentMode != PathDrawingMode.viewOnly) ...[
          const SizedBox(height: 10),
          _buildActionButtons(),
        ],
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Path Drawing Mode:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PathDrawingMode.values.map((mode) {
              return ChoiceChip(
                label: Text(_getModeLabel(mode)),
                selected: _currentMode == mode,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _currentMode = mode;
                      _resetSelection();
                    });
                  }
                },
                selectedColor: Colors.blue.withOpacity(0.3),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    String instruction = '';
    Color bgColor = Colors.blue.withOpacity(0.1);

    switch (_currentMode) {
      case PathDrawingMode.viewOnly:
        instruction = 'View mode: Tap nodes to see details';
        bgColor = Colors.grey.withOpacity(0.1);
        break;
      case PathDrawingMode.addNode:
        instruction = 'Add Node: Tap on the map to add a new navigation point';
        bgColor = Colors.green.withOpacity(0.1);
        break;
      case PathDrawingMode.removeNode:
        instruction = 'Remove Node: Tap on a node to delete it';
        bgColor = Colors.red.withOpacity(0.1);
        break;
      case PathDrawingMode.connectNodes:
        if (_connectingFromNode == null) {
          instruction = 'Connect Nodes: Tap on the first node to connect from';
        } else {
          instruction =
              'Connect Nodes: Tap on the second node to complete the connection';
        }
        bgColor = Colors.orange.withOpacity(0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getModeIcon(_currentMode),
            size: 16,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_currentMode == PathDrawingMode.connectNodes &&
              _connectingFromNode != null)
            ElevatedButton.icon(
              onPressed: _cancelConnection,
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
            ),
          ElevatedButton.icon(
            onPressed: _clearAllPaths,
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showPathSummary,
            icon: const Icon(Icons.info, size: 16),
            label: const Text('Summary'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[400],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getModeLabel(PathDrawingMode mode) {
    switch (mode) {
      case PathDrawingMode.viewOnly:
        return 'View';
      case PathDrawingMode.addNode:
        return 'Add Node';
      case PathDrawingMode.removeNode:
        return 'Remove Node';
      case PathDrawingMode.connectNodes:
        return 'Connect';
    }
  }

  IconData _getModeIcon(PathDrawingMode mode) {
    switch (mode) {
      case PathDrawingMode.viewOnly:
        return Icons.visibility;
      case PathDrawingMode.addNode:
        return Icons.add_location;
      case PathDrawingMode.removeNode:
        return Icons.remove_circle;
      case PathDrawingMode.connectNodes:
        return Icons.timeline;
    }
  }

  void _resetSelection() {
    _connectingFromNode = null;
  }

  void _cancelConnection() {
    setState(() {
      _connectingFromNode = null;
    });
  }

  void _clearAllPaths() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Paths'),
        content: const Text(
          'Are you sure you want to remove all navigation nodes and connections? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performClearAll();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _performClearAll() {
    // Remove all edges first
    for (final edge in widget.existingEdges.toList()) {
      widget.onEdgeRemoved(edge);
    }

    // Then remove all nodes
    for (final node in widget.existingNodes.toList()) {
      widget.onNodeRemoved(node);
    }

    _resetSelection();
  }

  void _showPathSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Path Network Summary'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Nodes: ${widget.existingNodes.length}'),
              Text('Total Connections: ${widget.existingEdges.length}'),
              const SizedBox(height: 16),
              const Text(
                'Nodes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (widget.existingNodes.isEmpty)
                const Text('No nodes created yet')
              else
                ...widget.existingNodes.map((node) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${node.label}'),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Handle map tap events based on current mode
  void handleMapTap(LatLng tappedLocation) {
    switch (_currentMode) {
      case PathDrawingMode.addNode:
        _addNodeAtLocation(tappedLocation);
        break;
      case PathDrawingMode.removeNode:
        _removeNodeAtLocation(tappedLocation);
        break;
      case PathDrawingMode.connectNodes:
        _handleNodeConnection(tappedLocation);
        break;
      case PathDrawingMode.viewOnly:
        _selectNodeAtLocation(tappedLocation);
        break;
    }
  }

  void _addNodeAtLocation(LatLng location) {
    // Convert to image coordinates (simplified)
    final dx = location.longitude;
    final dy = location.latitude;

    showDialog(
      context: context,
      builder: (context) {
        String nodeName = '';
        return AlertDialog(
          title: const Text('Add Navigation Node'),
          content: TextField(
            onChanged: (value) => nodeName = value,
            decoration: const InputDecoration(
              labelText: 'Node Name',
              hintText: 'Enter a name for this location',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nodeName.isNotEmpty) {
                  final newNode = NavigationNode(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    label: nodeName,
                    lat: location.latitude,
                    lng: location.longitude,
                    dx: dx,
                    dy: dy,
                    projectId: widget.project.id,
                  );
                  widget.onNodeAdded(newNode);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeNodeAtLocation(LatLng location) {
    // Find nearest node to the tapped location
    NavigationNode? nearestNode;
    double minDistance = double.infinity;

    for (final node in widget.existingNodes) {
      final distance = _calculateDistance(
        location.latitude,
        location.longitude,
        node.lat,
        node.lng,
      );

      if (distance < minDistance && distance < 0.001) {
        // Within ~100m
        minDistance = distance;
        nearestNode = node;
      }
    }

    if (nearestNode != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Node'),
          content: Text('Remove "${nearestNode!.label}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                widget.onNodeRemoved(nearestNode!);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }
  }

  void _handleNodeConnection(LatLng location) {
    final nearestNode = _findNearestNode(location);

    if (nearestNode == null) return;

    if (_connectingFromNode == null) {
      setState(() {
        _connectingFromNode = nearestNode;
      });
    } else if (_connectingFromNode!.id != nearestNode.id) {
      _createConnection(_connectingFromNode!, nearestNode);
      setState(() {
        _connectingFromNode = null;
      });
    }
  }

  void _selectNodeAtLocation(LatLng location) {
    final nearestNode = _findNearestNode(location);
    if (nearestNode != null) {
      _showNodeDetails(nearestNode);
    }
  }

  NavigationNode? _findNearestNode(LatLng location) {
    NavigationNode? nearestNode;
    double minDistance = double.infinity;

    for (final node in widget.existingNodes) {
      final distance = _calculateDistance(
        location.latitude,
        location.longitude,
        node.lat,
        node.lng,
      );

      if (distance < minDistance && distance < 0.001) {
        // Within ~100m
        minDistance = distance;
        nearestNode = node;
      }
    }

    return nearestNode;
  }

  void _createConnection(NavigationNode from, NavigationNode to) {
    final distance = _calculateDistance(from.lat, from.lng, to.lat, to.lng) *
        111320; // Convert to meters

    final newEdge = NavigationEdge(
      id: '${from.id}_${to.id}',
      fromNodeId: from.id,
      toNodeId: to.id,
      distance: distance,
      projectId: widget.project.id,
    );

    widget.onEdgeAdded(newEdge);
  }

  void _showNodeDetails(NavigationNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(node.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Coordinates: ${node.lat.toStringAsFixed(6)}, ${node.lng.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            Text('Connections: ${_getNodeConnectionCount(node)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  int _getNodeConnectionCount(NavigationNode node) {
    return widget.existingEdges
        .where((edge) => edge.fromNodeId == node.id || edge.toNodeId == node.id)
        .length;
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    final dx = lat1 - lat2;
    final dy = lng1 - lng2;
    return (dx * dx + dy * dy);
  }
}

enum PathDrawingMode {
  viewOnly,
  addNode,
  removeNode,
  connectNodes,
}
