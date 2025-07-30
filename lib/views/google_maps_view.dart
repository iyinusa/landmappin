import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' show max, cos, sin, atan2, sqrt, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/map_project.dart';
import '../models/map_point.dart';
import '../db/hive_boxes.dart';
import '../widgets/animated_fab_menu.dart';
import '../widgets/map_loading_widget.dart';
import '../widgets/animated_dialog.dart';
import '../widgets/custom_location_marker.dart';
import '../widgets/location_diagnostic_widget.dart';
import '../services/custom_navigation_controller.dart';
import '../services/location_service.dart';
import '../services/location_service_mixin.dart';
import '../models/navigation_node.dart';
import '../models/navigation_edge.dart';

class GoogleMapsView extends StatefulWidget {
  final MapProject project;
  const GoogleMapsView({super.key, required this.project});

  @override
  State<GoogleMapsView> createState() => _GoogleMapsViewState();
}

class _GoogleMapsViewState extends State<GoogleMapsView>
    with LocationServiceMixin {
  // Start navigation to a searched location using custom navigation
  Future<void> _searchAndStartNavigation(String query) async {
    if (query.trim().isEmpty) {
      _showLocationSelectionDialog();
      return;
    }

    final matchingPoints = _points
        .where(
            (point) => point.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (matchingPoints.isNotEmpty) {
      // final point = matchingPoints.first;
      // await _startCustomNavigation(point);
      // After navigation starts, update polylines to show pathway
      setState(() {
        _updatePolylines();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not found')),
      );
    }
  }

  // Start custom navigation to a specific point
  Future<void> _startCustomNavigation(MapPoint destination) async {
    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint(
          '[GoogleMapsView] Starting navigation to: ${destination.label}');

      // Validate prerequisites
      if (!await _validateNavigationPrerequisites()) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Find the navigation node closest to the destination point
      final destinationNodeId = await _findNearestNavigationNodeId(destination);

      if (destinationNodeId == null) {
        setState(() {
          _isLoading = false;
        });
        _showNavigationError(
          'Navigation Unavailable',
          'No navigation node found near "${destination.label}". This destination may not be reachable through the current navigation network.',
        );
        return;
      }

      debugPrint('[GoogleMapsView] Found destination node: $destinationNodeId');

      // Start custom navigation with detailed error handling
      final result =
          await _customNavigationController.startNavigationWithResult(
        destinationNodeId,
        widget.project.id,
      );

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        await _onNavigationStarted(destination);
      } else {
        _handleNavigationFailure(result.error, result.errorCode);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('[GoogleMapsView] Navigation error: $e');
      _showNavigationError(
        'Navigation Error',
        'An unexpected error occurred while starting navigation: ${e.toString()}',
      );
    }
  }

  /// Validate prerequisites for navigation
  Future<bool> _validateNavigationPrerequisites() async {
    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showNavigationError(
        'Location Permission Required',
        'Please enable location access to use navigation features.',
      );
      return false;
    }

    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showNavigationError(
        'Location Service Disabled',
        'Please enable location services on your device to use navigation.',
      );
      return false;
    }

    return true;
  }

  /// Handle successful navigation start
  Future<void> _onNavigationStarted(MapPoint destination) async {
    // Animate to the destination point
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(destination.lat, destination.lng),
        18.0,
      ),
    );

    _searchController.clear();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Navigation started to: ${destination.label}'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Stop',
          textColor: Colors.white,
          onPressed: _stopNavigation,
        ),
      ),
    );

    debugPrint(
        '[GoogleMapsView] Navigation successfully started to: ${destination.label}');
  }

  /// Handle navigation failure with specific error messages
  void _handleNavigationFailure(String? error, String? errorCode) {
    String title = 'Navigation Failed';
    String message = 'Unable to start navigation.';

    switch (errorCode) {
      case 'NO_LOCATION':
        title = 'Location Not Available';
        message =
            'Unable to determine your current location. Please ensure GPS is enabled and try again.';
        break;
      case 'NO_NODES':
        title = 'Navigation Data Missing';
        message =
            'No navigation points found for this map. Please add location markers first.';
        break;
      case 'NO_START_NODE':
        title = 'Starting Point Not Found';
        message = 'Cannot find a navigation point near your current location.';
        break;
      case 'NO_DESTINATION_NODE':
        title = 'Destination Not Found';
        message =
            'The selected destination is not accessible through the navigation network.';
        break;
      case 'NO_PATH':
        title = 'Route Not Available';
        message =
            'No route found between your location and the destination. The points may not be connected.';
        break;
      case 'LOCATION_TRACKING_FAILED':
        title = 'Location Tracking Failed';
        message =
            'Unable to start location tracking for navigation. Please check your device settings.';
        break;
      default:
        if (error != null && error.isNotEmpty) {
          message = error;
        }
        break;
    }

    _showNavigationError(title, message);
  }

  // Stop custom navigation
  void _stopNavigation() {
    _customNavigationController.stopNavigation();
    _searchController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation stopped')),
    );
  }

  // Find nearest navigation node to a map point
  Future<String?> _findNearestNavigationNodeId(MapPoint point) async {
    debugPrint(
        '[GoogleMapsView] Finding nearest navigation node for point: ${point.label}');

    try {
      // Always get fresh nodes from the custom navigation controller to ensure consistency
      final nodes = await _customNavigationController
          .getNavigationNodes(widget.project.id);

      if (nodes.isEmpty) {
        debugPrint(
            '[GoogleMapsView] No navigation nodes available for project ${widget.project.id}');
        return null;
      }

      debugPrint(
          '[GoogleMapsView] Searching among ${nodes.length} navigation nodes');

      // Find the closest navigation node to the destination point
      NavigationNode? nearestNode;
      double minDistance = double.infinity;

      for (final node in nodes) {
        final distance = _calculateDistance(
          point.lat,
          point.lng,
          node.lat,
          node.lng,
        );

        debugPrint(
            '[GoogleMapsView] Node ${node.id} (${node.label}) is ${distance.toStringAsFixed(2)}m away');

        if (distance < minDistance) {
          minDistance = distance;
          nearestNode = node;
        }
      }

      if (nearestNode != null) {
        debugPrint(
            '[GoogleMapsView] Found nearest node: ${nearestNode.id} (${nearestNode.label}) at ${minDistance.toStringAsFixed(2)}m');

        // For exact point matches, return the exact node ID
        if (minDistance < 1.0) {
          // Within 1 meter - essentially the same point
          debugPrint(
              '[GoogleMapsView] Exact match found for destination point');
          return nearestNode.id;
        }

        // For nearby points, check if there's a direct match by name/label
        for (final node in nodes) {
          if (node.label.toLowerCase() == point.label.toLowerCase() ||
              (node.lat == point.lat && node.lng == point.lng)) {
            debugPrint(
                '[GoogleMapsView] Direct label/coordinate match found: ${node.id}');
            return node.id;
          }
        }

        return nearestNode.id;
      } else {
        debugPrint('[GoogleMapsView] No nearest node found');
        return null;
      }
    } catch (e) {
      debugPrint('[GoogleMapsView] Error finding nearest navigation node: $e');
      return null;
    }
  }

  // Calculate distance between two points in meters
  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Calculate the center point of all mapped points for better positioning
  LatLng _calculateCenterPoint() {
    if (_points.isEmpty) {
      return const LatLng(0, 0);
    }

    final centerLat =
        _points.map((p) => p.lat).reduce((a, b) => a + b) / _points.length;
    final centerLng =
        _points.map((p) => p.lng).reduce((a, b) => a + b) / _points.length;

    return LatLng(centerLat, centerLng);
  }

  /// Calculate optimal zoom level based on the spread of points
  double _calculateOptimalZoom() {
    if (_points.length < 2) {
      return 15.0; // Default zoom for single point
    }

    final lats = _points.map((p) => p.lat).toList();
    final lngs = _points.map((p) => p.lng).toList();

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    // Calculate the distance span to determine zoom level
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final maxSpan = max(latSpan, lngSpan);

    // Zoom levels based on coordinate span (approximate)
    if (maxSpan < 0.001) return 18.0; // Very close points
    if (maxSpan < 0.005) return 16.0; // Close points
    if (maxSpan < 0.01) return 15.0; // Nearby points
    if (maxSpan < 0.05) return 13.0; // Medium distance
    if (maxSpan < 0.1) return 12.0; // Wider area
    if (maxSpan < 0.5) return 10.0; // Large area
    return 8.0; // Very large area
  }

  // Show navigation error dialog
  void _showNavigationError(String title, String message) {
    ModernAlertDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.error_outline,
          color: Colors.red.shade600,
          size: 32,
        ),
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        ModernDialogButton(
          text: 'OK',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polygon> _overlayPolygons = {};
  Set<Polyline> _polylines = {}; // Added for navigation routes
  Set<GroundOverlay> _groundOverlays = {}; // Added for ground overlay support
  List<MapPoint> _points = [];
  Position? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  double _overlayOpacity = 0.7; // Default opacity at 70%
  bool _showOverlay = true;
  Uint8List? _imageBytes;
  MapType _currentMapType = MapType.normal; // Add map type state

  // Custom markers
  BitmapDescriptor? _customLocationMarker;
  BitmapDescriptor? _customDestinationMarker;
  BitmapDescriptor? _customPointMarker;

  // Custom Navigation related variables
  final CustomNavigationController _customNavigationController =
      CustomNavigationController();
  bool _isNavigating = false;
  final TextEditingController _searchController = TextEditingController();

  // Path drawing variables
  List<NavigationNode> _navigationNodes = [];
  List<NavigationEdge> _navigationEdges = [];
  bool _isPathDrawingMode = false;

  // Image overlay bounds - calculated from corner points
  LatLngBounds? _imageBounds;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _setupNavigationListener();
    _initializeRealTimeLocationTracking();
  }

  void _initializeRealTimeLocationTracking() {
    // Initialize location service and start real-time tracking
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // First ensure location service is initialized
      final locationService = LocationService();
      bool initialized = await locationService.initialize();

      if (!initialized) {
        debugPrint('❌ Failed to initialize location service');
        return;
      }

      // Start real-time tracking with optimal settings
      bool success = await startRealTimeTracking(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1.0, // Update every 1 meter for better tracking
        updateInterval: const Duration(
            milliseconds: 500), // 500ms updates for smoother experience
      );

      if (success) {
        debugPrint('✅ Real-time location tracking started successfully');
        // Force initial location update
        await _getCurrentLocation();
      } else {
        debugPrint('❌ Failed to start real-time location tracking');
      }
    });
  }

  @override
  void onLocationUpdate(Position position) {
    // Update current position when location changes
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });

      // Update markers to show new current location with animation
      _updateMarkersWithAnimation();

      // Update navigation polylines to include current location
      if (_isNavigating) {
        _updatePolylines();
        _smoothFollowUserLocation(position);
      }

      // Debug logging for location updates
      debugPrint(
          '📍 Location updated: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} | Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
    }
  }

  @override
  void onLatLngUpdate(LatLng latLng) {
    // Handle LatLng updates if needed for navigation
    if (mounted && _isNavigating) {
      // This helps with smoother navigation updates by triggering a rebuild
      setState(() {});
    }
  }

  /// Smooth camera animation to follow user location during navigation
  void _smoothFollowUserLocation(Position position) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 18.0,
            bearing: position.heading,
            tilt: 45.0, // Add slight tilt for 3D effect
          ),
        ),
      );
    }
  }

  /// Update markers with smooth animation
  void _updateMarkersWithAnimation() async {
    // Recreate markers with updated position
    await _createMarkers();

    // Add pulse animation to current location marker
    if (_currentPosition != null && _mapController != null) {
      // Trigger a small zoom animation to show movement
      final currentZoom = await _mapController!.getZoomLevel();
      _mapController!.animateCamera(
        CameraUpdate.zoomTo(currentZoom + 0.1),
      );

      // Return to original zoom smoothly
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.zoomTo(currentZoom),
          );
        }
      });
    }
  }

  void _setupNavigationListener() {
    _customNavigationController.addListener(() {
      setState(() {
        _isNavigating = _customNavigationController.state ==
            CustomNavigationState.navigating;
        _updateNavigationDisplay();
      });
    });
  }

  void _updateNavigationDisplay() {
    // Update polylines with navigation route
    _updatePolylines();
  }

  void _updatePolylines() {
    _polylines.clear();

    // Add custom navigation route with enhanced styling
    if (_customNavigationController.currentPath != null) {
      final polylinePoints =
          _customNavigationController.getNavigationPolylinePoints();
      if (polylinePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('custom_navigation_route'),
            points: polylinePoints,
            color: Colors.blue.shade600, // More vibrant blue
            width: 8, // Increased from 6 for better visibility
            patterns: [], // Solid line instead of dashed for active navigation
            geodesic: true, // Enable geodesic lines for accurate routes
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        // Add a white outline for better contrast
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('custom_navigation_route_outline'),
            points: polylinePoints,
            color: Colors.white,
            width: 12, // Slightly wider than the main line
            patterns: [],
            geodesic: true,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        debugPrint(
            '🗺️ Navigation polyline updated with ${polylinePoints.length} points');
      }
    }

    // Add navigation edges for path drawing mode
    if (_isPathDrawingMode) {
      for (final edge in _navigationEdges) {
        final fromNode = _navigationNodes.firstWhere(
          (node) => node.id == edge.fromNodeId,
          orElse: () => NavigationNode(
              id: '', label: '', lat: 0, lng: 0, dx: 0, dy: 0, projectId: ''),
        );
        final toNode = _navigationNodes.firstWhere(
          (node) => node.id == edge.toNodeId,
          orElse: () => NavigationNode(
              id: '', label: '', lat: 0, lng: 0, dx: 0, dy: 0, projectId: ''),
        );

        if (fromNode.id.isNotEmpty && toNode.id.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('edge_${edge.id}'),
              points: [
                LatLng(fromNode.lat, fromNode.lng),
                LatLng(toNode.lat, toNode.lng),
              ],
              color: Colors.orange,
              width: 5,
              patterns: [PatternItem.dash(5), PatternItem.gap(5)],
            ),
          );
        }
      }
    }
  }

  Future<void> _initializeMap() async {
    try {
      // Get current location
      await _getCurrentLocation();

      // Initialize custom markers
      await _initializeCustomMarkers();

      // Load map points
      await _loadMapPoints();

      // Create image overlay bounds
      await _createImageOverlayBounds();

      // Load image bytes
      await _loadImageBytes();

      // Create markers
      await _createMarkers();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize map: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadImageBytes() async {
    try {
      final String imagePath = widget.project.imagePath;

      if (imagePath.isEmpty) {
        print('Image path is empty');
        return;
      }

      if (imagePath.startsWith('assets/')) {
        // Load from assets
        final ByteData data = await rootBundle.load(imagePath);
        setState(() {
          _imageBytes = data.buffer.asUint8List();
        });
      } else {
        // Load from file
        final file = File(imagePath);
        if (await file.exists()) {
          setState(() {
            _imageBytes = file.readAsBytesSync();
          });
        } else {
          print('Image file does not exist: $imagePath');
          // Try to search in app documents directory
          print('Full path checked: ${file.absolute.path}');
          print('Directory exists: ${file.parent.existsSync()}');
          if (file.parent.existsSync()) {
            print('Files in directory:');
            file.parent.listSync().forEach((f) => print("  ${f.path}"));
          }
        }
      }
    } catch (e) {
      print('Error loading image bytes: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Use the optimized location service
      final position = await getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadMapPoints() async {
    final box = HiveBoxes.getMapPointsBox();
    final projectPoints = box.values
        .where((point) => point.projectId == widget.project.id)
        .toList();

    setState(() {
      _points = projectPoints;
    });
  }

  // Load navigation data (nodes and edges) for path drawing and navigation
  Future<void> _loadNavigationData() async {
    // Load navigation nodes from Hive or create from map points
    // For now, we'll create navigation nodes from map points
    // In a full implementation, you'd have separate storage for navigation nodes

    final nodes = <NavigationNode>[];
    for (int i = 0; i < _points.length; i++) {
      final point = _points[i];
      nodes.add(NavigationNode(
        id: 'node_${point.key ?? i}',
        label: point.label,
        lat: point.lat,
        lng: point.lng,
        dx: point.dx,
        dy: point.dy,
        projectId: point.projectId,
      ));
    }

    // Create basic connectivity between nearby nodes (within 100 meters)
    final edges = <NavigationEdge>[];
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final distance = _calculateDistance(
          nodes[i].lat,
          nodes[i].lng,
          nodes[j].lat,
          nodes[j].lng,
        );

        // Create edges for nearby nodes (within 100 meters)
        if (distance <= 100) {
          edges.add(NavigationEdge(
            id: 'edge_${nodes[i].id}_${nodes[j].id}',
            fromNodeId: nodes[i].id,
            toNodeId: nodes[j].id,
            distance: distance,
            isBidirectional: true,
            isAccessible: true,
            projectId: widget.project.id,
          ));
        }
      }
    }

    setState(() {
      _navigationNodes = nodes;
      _navigationEdges = edges;
    });
  }

  Future<void> _createImageOverlayBounds() async {
    if (_points.length < 2) {
      print('Need at least 2 points to create image overlay');
      return;
    }

    try {
      // Check for specific corner labels first
      MapPoint? southwestPoint = _findCornerPoint(['southwest', 'sw', 'se']);
      MapPoint? northeastPoint = _findCornerPoint(['northeast', 'ne', 'ne']);

      double minLat, maxLat, minLng, maxLng;
      String boundsMethod;

      if (southwestPoint != null && northeastPoint != null) {
        debugPrint(
            'Using corner points for bounds: ${southwestPoint.label}, ${northeastPoint.label}');
        // Use specific corner points if found
        minLat = southwestPoint.lat;
        maxLat = northeastPoint.lat;
        minLng = southwestPoint.lng;
        maxLng = northeastPoint.lng;
        boundsMethod = 'corner points';

        debugPrint('Using corner points for bounds:');
        debugPrint(
            '  Southwest point: ${southwestPoint.label} (${southwestPoint.lat}, ${southwestPoint.lng})');
        debugPrint(
            '  Northeast point: ${northeastPoint.label} (${northeastPoint.lat}, ${northeastPoint.lng})');
      } else {
        // Fall back to auto-calculation using all points with center-based expansion
        final centerPoint = _calculateCenterPoint();
        final lats = _points.map((p) => p.lat).toList();
        final lngs = _points.map((p) => p.lng).toList();

        minLat = lats.reduce((a, b) => a < b ? a : b);
        maxLat = lats.reduce((a, b) => a > b ? a : b);
        minLng = lngs.reduce((a, b) => a < b ? a : b);
        maxLng = lngs.reduce((a, b) => a > b ? a : b);

        // Add padding based on the spread around center point for better positioning
        final latSpread = maxLat - minLat;
        final lngSpread = maxLng - minLng;
        final padding = max(latSpread, lngSpread) * 0.1; // 10% padding

        minLat -= padding;
        maxLat += padding;
        minLng -= padding;
        maxLng += padding;

        boundsMethod = 'auto-calculation with center-based padding';

        debugPrint(
            'No corner points found, using center-based auto-calculation from all ${_points.length} points');
        debugPrint('Center point: $centerPoint');
        debugPrint('Applied padding: ${padding.toStringAsFixed(6)}°');
      }

      // Create bounds
      _imageBounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Log the bounds for debugging
      debugPrint('Image overlay bounds calculated using $boundsMethod:');
      debugPrint('  Southwest: ${_imageBounds!.southwest}');
      debugPrint('  Northeast: ${_imageBounds!.northeast}');
      debugPrint(
          '  Points used: ${_points.map((p) => '${p.label}: (${p.lat}, ${p.lng})').join(', ')}');

      // Create boundary polygon to show the image bounds
      await _createBoundaryPolygon();
    } catch (e) {
      print('Error creating image overlay bounds: $e');
    }
  }

  /// Finds a point with a label matching the corner keywords
  MapPoint? _findCornerPoint(List<String> keywords) {
    for (final point in _points) {
      final label = point.label.toLowerCase().trim();
      for (final keyword in keywords) {
        if (label == keyword || label.contains(keyword)) {
          return point;
        }
      }
    }
    return null;
  }

  Future<void> _createBoundaryPolygon() async {
    if (_imageBounds == null) return;

    final sw = _imageBounds!.southwest;
    final ne = _imageBounds!.northeast;

    // Create an invisible polygon for overlay bounds (no stroke, no fill)
    final overlayPolygon = Polygon(
      polygonId: const PolygonId('image_overlay_bounds'),
      points: [
        sw,
        LatLng(sw.latitude, ne.longitude),
        ne,
        LatLng(ne.latitude, sw.longitude),
      ],
      strokeColor: Colors.transparent, // Make stroke invisible
      strokeWidth: 0, // No stroke width
      fillColor: Colors.transparent, // Make fill invisible
    );

    setState(() {
      _overlayPolygons = {overlayPolygon};
    });

    // Create ground overlay if image is available
    if (_imageBytes != null) {
      await _createGroundOverlay();
    }
  }

  Future<void> _createGroundOverlay() async {
    if (_imageBounds == null || _imageBytes == null) return;

    try {
      // Create BytesMapBitmap from image bytes with no scaling for precise placement
      final mapBitmap = BytesMapBitmap(
        _imageBytes!,
        bitmapScaling: MapBitmapScaling.none, // Critical for precise placement
      );

      // Calculate center point of all mapped locations for better anchoring
      final centerPoint = _calculateCenterPoint();

      // Create ground overlay using precise bounds for best alignment
      // The bounds automatically encompass all points with optimal image placement
      final groundOverlay = GroundOverlay.fromBounds(
        groundOverlayId: const GroundOverlayId('project_image'),
        image: mapBitmap,
        bounds: _imageBounds!,
        anchor: const Offset(0.5, 0.5), // Center anchor for balanced placement
        bearing: 0.0, // No rotation initially
        transparency: 1.0 - _overlayOpacity,
        zIndex: 1,
        visible: _showOverlay,
        clickable: true, // Allow map interaction through overlay
      );

      setState(() {
        _groundOverlays = {groundOverlay};
      });

      debugPrint(
          'GroundOverlay created successfully using ${_points.length} points');
      debugPrint('Center point: $centerPoint');
      debugPrint(
          'Bounds: ${_imageBounds!.southwest} to ${_imageBounds!.northeast}');
    } catch (e) {
      debugPrint('Error creating ground overlay: $e');
      // Fallback to empty set if creation fails
      setState(() {
        _groundOverlays = {};
      });
    }
  }

  /// Initialize custom animated markers
  Future<void> _initializeCustomMarkers() async {
    try {
      // Create custom animated location marker (larger size for better visibility)
      _customLocationMarker =
          await CustomLocationMarker.createLargeAnimatedLocationMarker(
        size: 100.0, // Much larger for better visibility
        primaryColor: Colors.blue,
        pulseColor: Colors.lightBlue,
        withPulse: true,
        withAccuracyCircle: true,
      );

      // Create custom destination marker (increased size)
      _customDestinationMarker =
          await CustomLocationMarker.createDestinationMarker(
        size: 120.0, // Increased from 100.0
        color: Colors.orange,
      );

      // Create custom point marker (increased size)
      _customPointMarker = await CustomLocationMarker.createPointMarker(
        size: 110.0, // Increased from 90.0
        color: Colors.red,
      );

      debugPrint('✅ Custom markers initialized with enhanced sizes');
    } catch (e) {
      debugPrint('❌ Error creating custom markers: $e');
      // Fallback to default markers if custom creation fails
    }
  }

  Future<void> _createMarkers() async {
    Set<Marker> markers = {};

    // Create markers for all points with custom styling
    for (int i = 0; i < _points.length; i++) {
      final point = _points[i];
      final markerId = MarkerId('point_$i');

      markers.add(Marker(
        markerId: markerId,
        position: LatLng(point.lat, point.lng),
        infoWindow: InfoWindow(
          title: point.label,
          snippet:
              'Lat: ${point.lat.toStringAsFixed(6)}, Lng: ${point.lng.toStringAsFixed(6)}',
          onTap: () => _showPointDetails(point),
        ),
        icon: _customPointMarker ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        onTap: () => _showPointDetails(point),
      ));
    }

    // Add navigation node markers if in path drawing mode
    if (_isPathDrawingMode) {
      for (int i = 0; i < _navigationNodes.length; i++) {
        final node = _navigationNodes[i];
        final markerId = MarkerId('nav_node_${node.id}');

        markers.add(Marker(
          markerId: markerId,
          position: LatLng(node.lat, node.lng),
          infoWindow: InfoWindow(
            title: '🧭 ${node.label}',
            snippet: 'Navigation Node',
          ),
          icon: _customDestinationMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
      }
    }

    // Add only one current location marker at a time
    if (_currentPosition != null) {
      markers.removeWhere((m) => m.markerId.value == 'current_location');
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position:
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: _customLocationMarker ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: const Offset(0.5, 0.5),
      ));
    }

    setState(() {
      _markers = markers;
    });
  }

  // Alias for _createMarkers to be called from other methods
  void _updateMarkers() {
    _createMarkers();
  }

  void _showPointDetails(MapPoint point) {
    AnimatedBottomSheet.show(
      context: context,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.black, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point.label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Latitude', '${point.lat.toStringAsFixed(6)}°'),
            _buildDetailRow('Longitude', '${point.lng.toStringAsFixed(6)}°'),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Distance',
                '${_calculateDistanceFromPosition(_currentPosition!, LatLng(point.lat, point.lng)).toStringAsFixed(0)}m',
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToPoint(point),
                icon: const Icon(Icons.directions),
                label: const Text('Navigate Here'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to calculate distance from current position to a point
  double _calculateDistanceFromPosition(Position from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  void _navigateToPoint(MapPoint point) {
    Navigator.pop(context);
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(point.lat, point.lng),
          18.0,
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Center map on image bounds or center point of all points for better positioning
    if (_imageBounds != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(_imageBounds!, 100),
      );
    } else if (_points.isNotEmpty) {
      // Calculate center point for better positioning
      final centerPoint = _calculateCenterPoint();
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          centerPoint,
          _calculateOptimalZoom(),
        ),
      );
    } else if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0,
        ),
      );
    }

    // show overlay if available
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_imageBytes != null && _showOverlay) {
        _createGroundOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.project.name} - Map Overlay',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showMapInfo,
            icon: const Icon(Icons.info_outline),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'satellite':
                  _changeMapType(MapType.satellite);
                  break;
                case 'normal':
                  _changeMapType(MapType.normal);
                  break;
                case 'hybrid':
                  _changeMapType(MapType.hybrid);
                  break;
                case 'refresh':
                  _refreshMap();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'normal',
                child: Row(
                  children: [
                    Icon(
                      _currentMapType == MapType.normal ? Icons.check : null,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Normal View'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'satellite',
                child: Row(
                  children: [
                    Icon(
                      _currentMapType == MapType.satellite ? Icons.check : null,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Satellite View'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'hybrid',
                child: Row(
                  children: [
                    Icon(
                      _currentMapType == MapType.hybrid ? Icons.check : null,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Hybrid View'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh Map')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? MapLoadingWidget(
              message: 'Loading map overlay...',
              project: widget.project,
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _initializeMap();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition != null
                            ? LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude)
                            : const LatLng(
                                37.7749, -122.4194), // San Francisco default
                        zoom: 15.0,
                      ),
                      markers: _markers,
                      polylines: _polylines, // Added for navigation routes
                      polygons: _overlayPolygons,
                      groundOverlays: _groundOverlays, // Added ground overlays
                      myLocationEnabled:
                          false, // Disabled to use custom location marker
                      myLocationButtonEnabled:
                          false, // Disabled to use custom location button
                      mapType: _currentMapType,
                      onTap: _onMapTap,
                    ),
                    // Info overlay showing image bounds and overlay settings
                    if (_imageBounds != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showOverlay
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Image overlay: ${_showOverlay ? "On" : "Off"} • Opacity: ${(_overlayOpacity * 100).toInt()}% • ${_points.length} points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Navigation Search Bar
                    // Positioned(
                    //   top: _imageBounds != null ? 70 : 16,
                    //   left: 16,
                    //   right: 16,
                    //   child: _buildNavigationSearchBar(),
                    // ),
                    // Navigation Instructions Panel
                    if (_isNavigating)
                      Positioned(
                        bottom: 100,
                        left: 16,
                        right: 16,
                        child: _buildNavigationInstructions(),
                      ),

                    // Real-time Location Pulse Overlay
                    if (_currentPosition != null && _mapController != null)
                      _buildLocationPulseOverlay(),
                  ],
                ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedFabMenu(
        primaryColor: Colors.black,
        backgroundColor: Colors.white,
        toggleIcon: Icons.tune,
        closeIcon: Icons.close,
        menuItems: [
          FabMenuItem(
            icon: Icons.bug_report,
            label: 'Debug',
            backgroundColor: Colors.grey[600],
            onPressed: _showDebugInfo,
          ),
          FabMenuItem(
            icon: Icons.search,
            label: 'Search',
            onPressed: _showSearchDialog,
          ),
          FabMenuItem(
            icon: Icons.my_location,
            label: 'My Location',
            backgroundColor: Colors.blue,
            onPressed: _centerOnUserLocation,
          ),
          FabMenuItem(
            icon: Icons.opacity,
            label: 'Opacity',
            onPressed: _showOpacityDialog,
          ),
          FabMenuItem(
            icon: _showOverlay ? Icons.visibility : Icons.visibility_off,
            label: _showOverlay ? 'Hide Overlay' : 'Show Overlay',
            onPressed: () async {
              setState(() {
                _showOverlay = !_showOverlay;
              });
              await _createGroundOverlay();
            },
          ),
          FabMenuItem(
            icon: Icons.center_focus_strong,
            label: 'Center Map',
            onPressed: _centerOnImageBounds,
          ),
          FabMenuItem(
            icon: _isPathDrawingMode ? Icons.route : Icons.edit_road,
            label: _isPathDrawingMode ? 'Exit Path Mode' : 'Path Drawing',
            backgroundColor: _isPathDrawingMode ? Colors.orange : Colors.blue,
            onPressed: _togglePathDrawingMode,
          ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng latLng) {
    // If path drawing mode is enabled, add navigation nodes
    if (_isPathDrawingMode) {
      _addNavigationNode(latLng);
      return;
    }

    // Otherwise, show add point dialog as before
    ModernAlertDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add_location,
          color: Colors.blue.shade600,
          size: 32,
        ),
      ),
      title: const Text('Add Point'),
      content: Text(
          'Add a new point at ${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}?'),
      actions: [
        ModernDialogButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        ModernDialogButton(
          text: 'Add',
          isPrimary: true,
          onPressed: () {
            Navigator.pop(context);
            _showAddPointDialog(latLng);
          },
        ),
      ],
    );
  }

  // Add navigation node when in path drawing mode
  Future<void> _addNavigationNode(LatLng latLng) async {
    final labelController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Navigation Node'),
        content: TextField(
          controller: labelController,
          decoration: const InputDecoration(
            labelText: 'Node Name',
            hintText: 'Enter a name for this navigation point',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, labelController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newNode = NavigationNode(
        id: 'node_${DateTime.now().millisecondsSinceEpoch}',
        label: result,
        lat: latLng.latitude,
        lng: latLng.longitude,
        dx: 0, // Will be calculated if needed
        dy: 0, // Will be calculated if needed
        projectId: widget.project.id,
      );

      setState(() {
        _navigationNodes.add(newNode);
      });

      // Add edges to nearby nodes (within 50 meters)
      for (final existingNode
          in _navigationNodes.where((n) => n.id != newNode.id)) {
        final distance = _calculateDistance(
          newNode.lat,
          newNode.lng,
          existingNode.lat,
          existingNode.lng,
        );

        if (distance <= 50) {
          final edge = NavigationEdge(
            id: 'edge_${newNode.id}_${existingNode.id}',
            fromNodeId: newNode.id,
            toNodeId: existingNode.id,
            distance: distance,
            isBidirectional: true,
            isAccessible: true,
            projectId: widget.project.id,
          );

          setState(() {
            _navigationEdges.add(edge);
          });
        }
      }

      // Update polylines to show new edges
      _updatePolylines();

      // Update markers
      _updateMarkers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added navigation node: $result')),
      );
    }
  }

  void _showAddPointDialog(LatLng latLng) {
    final labelController = TextEditingController();

    ModernAlertDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.location_on,
          color: Colors.green.shade600,
          size: 32,
        ),
      ),
      title: const Text('New Point'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: labelController,
            decoration: InputDecoration(
              labelText: 'Point Label',
              hintText: 'Enter a name for this point',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.my_location, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Coordinates: ${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ModernDialogButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        ModernDialogButton(
          text: 'Add Point',
          isPrimary: true,
          onPressed: () async {
            if (labelController.text.trim().isNotEmpty) {
              await _addNewPoint(latLng, labelController.text.trim());
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  Future<void> _addNewPoint(LatLng latLng, String label) async {
    // Calculate approximate dx, dy based on image bounds
    double dx = 0, dy = 0;
    if (_imageBounds != null) {
      final sw = _imageBounds!.southwest;
      final ne = _imageBounds!.northeast;

      dx = ((latLng.longitude - sw.longitude) / (ne.longitude - sw.longitude)) *
          300;
      dy =
          ((ne.latitude - latLng.latitude) / (ne.latitude - sw.latitude)) * 300;
    }

    final newPoint = MapPoint(
      label: label,
      dx: dx,
      dy: dy,
      lat: latLng.latitude,
      lng: latLng.longitude,
      projectId: widget.project.id,
    );

    final box = HiveBoxes.getMapPointsBox();
    await box.add(newPoint);

    await _loadMapPoints();
    await _createMarkers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added point: $label')),
    );
  }

  void _changeMapType(MapType mapType) {
    setState(() {
      _currentMapType = mapType;
    });

    // Force map to refresh by animating to current position
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Map type changed to ${mapType.toString().split('.').last}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _centerOnUserLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 18.0,
            bearing: _currentPosition!.heading,
            tilt: 45.0,
          ),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.my_location, color: Colors.white),
              SizedBox(width: 8),
              Text('Centered on your location'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _centerOnImageBounds() {
    if (_imageBounds != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(_imageBounds!, 100),
      );
    } else if (_points.isNotEmpty && _mapController != null) {
      // Use center point for better positioning instead of just first point
      final centerPoint = _calculateCenterPoint();
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          centerPoint,
          _calculateOptimalZoom(),
        ),
      );
    }
  }

  void _showMapInfo() {
    ModernAlertDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.info_outline,
          color: Colors.blue.shade600,
          size: 32,
        ),
      ),
      title: const Text('Map Overlay Info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Project', widget.project.name),
          _buildInfoRow('Total Points', '${_points.length}'),
          if (_imageBounds != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
                'Image Overlay', 'Active', Icons.check_circle, Colors.green),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Bounds: ${_imageBounds!.southwest.latitude.toStringAsFixed(4)}, ${_imageBounds!.southwest.longitude.toStringAsFixed(4)} to ${_imageBounds!.northeast.latitude.toStringAsFixed(4)}, ${_imageBounds!.northeast.longitude.toStringAsFixed(4)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ] else
            _buildInfoRow('Image Overlay', 'Requires 2+ points', Icons.warning,
                Colors.orange),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: The image overlay automatically calculates bounds using all map points for optimal positioning.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ModernDialogButton(
          text: 'Close',
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      [IconData? icon, Color? iconColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor ?? Colors.grey),
            const SizedBox(width: 8),
          ],
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();

    ModernAlertDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.search,
          color: Colors.purple.shade600,
          size: 32,
        ),
      ),
      title: const Text('Search Location'),
      content: TextField(
        controller: searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Enter point name...',
          prefixIcon: const Icon(Icons.location_searching),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.purple.shade300, width: 2),
          ),
        ),
      ),
      actions: [
        ModernDialogButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        ModernDialogButton(
          text: 'Search',
          isPrimary: true,
          onPressed: () {
            Navigator.pop(context);
            _searchLocation(searchController.text);
          },
        ),
      ],
    );
  }

  void _searchLocation(String query) {
    final matchingPoints = _points
        .where(
            (point) => point.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (matchingPoints.isNotEmpty) {
      final point = matchingPoints.first;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(point.lat, point.lng),
          18.0,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found: ${point.label}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not found')),
      );
    }
  }

  void _refreshMap() {
    setState(() {
      _isLoading = true;
    });
    _initializeMap();
  }

  void _showOpacityDialog() {
    ModernAlertDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.opacity,
          color: Colors.orange.shade600,
          size: 32,
        ),
      ),
      title: const Text('Adjust Overlay Opacity'),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Opacity: ${(_overlayOpacity * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.orange.shade400,
                        inactiveTrackColor: Colors.orange.shade100,
                        thumbColor: Colors.orange.shade600,
                        overlayColor: Colors.orange.shade100,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 12),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _overlayOpacity,
                        min: 0.2,
                        max: 1.0,
                        divisions: 8,
                        label: '${(_overlayOpacity * 100).toInt()}%',
                        onChanged: (value) async {
                          setState(() {
                            _overlayOpacity = value;
                          });
                          // Update parent state
                          this.setState(() {});
                          // Update ground overlay with new opacity
                          await _createGroundOverlay();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        ModernDialogButton(
          text: 'Close',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _showDebugInfo() {
    final imagePath = widget.project.imagePath;
    bool fileExists = false;
    String fileSize = 'N/A';
    String directoryContents = 'N/A';

    try {
      if (!imagePath.startsWith('assets/')) {
        final file = File(imagePath);
        fileExists = file.existsSync();
        if (fileExists) {
          fileSize = '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB';
        }

        if (file.parent.existsSync()) {
          final dirContents = file.parent.listSync();
          directoryContents = dirContents
              .map((f) =>
                  '- ${f.path.split('/').last} ${f is File ? "(${(f.statSync().size / 1024).toStringAsFixed(1)} KB)" : "(dir)"}')
              .join('\n');
        }
      }
    } catch (e) {
      directoryContents = 'Error getting directory: $e';
    }

    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.bug_report_outlined,
        color: Colors.blue,
        size: 48,
      ),
      title: const Text('Image Debug Info'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Project: ${widget.project.name}'),
          const Divider(),
          const Text('Image Info:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Path: $imagePath'),
          Text('File exists: $fileExists'),
          Text('File size: $fileSize'),
          Text(
              'Bytes loaded: ${_imageBytes != null ? '${(_imageBytes!.length / 1024).toStringAsFixed(1)} KB' : 'Not loaded'}'),
          const SizedBox(height: 10),
          const Text('Overlay Info:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Bounds: ${_imageBounds?.toString() ?? 'Not set'}'),
          Text('Overlay visible: $_showOverlay'),
          Text('Opacity: ${(_overlayOpacity * 100).toInt()}%'),
          Text('Ground overlays: ${_groundOverlays.length}'),
          const SizedBox(height: 10),
          const Text('Location Info:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
              'Current Position: ${_currentPosition != null ? "${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}" : "None"}'),
          Text('Navigation Active: ${_isNavigating ? "Yes ✅" : "No ❌"}'),
          const SizedBox(height: 10),
          const Text('All Points:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...(_points.map((p) => Text(
              '  ${p.label}: (${p.lat.toStringAsFixed(6)}, ${p.lng.toStringAsFixed(6)})'))),
          const SizedBox(height: 10),
          const Text('Directory Contents:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(directoryContents),
        ],
      ),
      actions: [
        ModernDialogButton(
          text: 'Location Diagnostics',
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LocationDiagnosticWidget(),
              ),
            );
          },
        ),
        ModernDialogButton(
          text: 'Reload Image',
          onPressed: () {
            // Reload image
            _loadImageBytes();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reloading image...')),
            );
          },
        ),
        ModernDialogButton(
          text: 'Close',
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // Navigation UI Methods
  // Widget _buildNavigationSearchBar() {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 4),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.2),
  //           blurRadius: 8,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: TextField(
  //             controller: _searchController,
  //             decoration: const InputDecoration(
  //               hintText: 'Search for a location...',
  //               border: InputBorder.none,
  //               contentPadding: EdgeInsets.symmetric(vertical: 15),
  //               prefixIcon: Icon(Icons.search, color: Colors.grey),
  //             ),
  //             onSubmitted: (value) => _searchAndStartNavigation(value),
  //           ),
  //         ),
  //         if (_isNavigating)
  //           IconButton(
  //             icon: const Icon(Icons.close, color: Colors.red),
  //             onPressed: _stopNavigation,
  //           ),
  //         IconButton(
  //           icon: const Icon(Icons.directions, color: Colors.blue),
  //           onPressed: () => _searchAndStartNavigation(_searchController.text),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildNavigationInstructions() {
    if (!_isNavigating || _customNavigationController.currentPath == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.navigation,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customNavigationController
                              .currentInstruction?.instruction ??
                          'Follow the blue route to your destination',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_customNavigationController.remainingDistance} • ${_customNavigationController.remainingTime}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_customNavigationController.distanceToNext > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'In ${_customNavigationController.distanceToNext.round()}m',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build location pulse overlay widget for real-time tracking
  Widget _buildLocationPulseOverlay() {
    return FutureBuilder<ScreenCoordinate>(
      future: _mapController!.getScreenCoordinate(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final screenCoordinate = snapshot.data!;

        // Make the pulse overlay smaller and ensure only one overlay is shown
        return Positioned(
          left: screenCoordinate.x.toDouble() - 20, // Center for smaller size
          top: screenCoordinate.y.toDouble() - 20,
          child: IgnorePointer(
            child: CustomLocationMarker.createPulsingLocationWidget(
              size: 40.0, // Reduced size for less intrusive marker
              color: Colors.blue.withOpacity(0.85),
            ),
          ),
        );
      },
    );
  }

  // Show location selection dialog for navigation
  Future<void> _showLocationSelectionDialog() async {
    if (_points.isEmpty) {
      _showNavigationError('No Locations Available',
          'Add some points to the map first before using navigation.');
      return;
    }

    await ModernAlertDialog.show(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.location_on,
          color: Colors.blue.shade600,
          size: 32,
        ),
      ),
      title: const Text('Select Destination'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose a location to navigate to:'),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: _points
                    .map((point) => ListTile(
                          leading:
                              const Icon(Icons.location_on, color: Colors.blue),
                          title: Text(point.label),
                          subtitle: Text(
                              '${point.lat.toStringAsFixed(4)}, ${point.lng.toStringAsFixed(4)}'),
                          onTap: () async {
                            Navigator.pop(context);
                            // await _startCustomNavigation(point);
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        ModernDialogButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // Toggle path drawing mode
  void _togglePathDrawingMode() {
    setState(() {
      _isPathDrawingMode = !_isPathDrawingMode;
    });

    // Load navigation data when entering path drawing mode
    if (_isPathDrawingMode) {
      _loadNavigationData();
    }

    // Update polylines to show/hide path edges
    _updatePolylines();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPathDrawingMode
            ? 'Path Drawing Mode: ON. Tap map to add navigation nodes.'
            : 'Path Drawing Mode: OFF'),
      ),
    );
  }
}

// EnhancedImageOverlay: shows the image with adjustable opacity and better error handling
class EnhancedImageOverlay extends StatefulWidget {
  final GoogleMapController mapController;
  final Uint8List imageBytes;
  final LatLngBounds bounds;
  final double opacity;

  const EnhancedImageOverlay({
    super.key,
    required this.mapController,
    required this.imageBytes,
    required this.bounds,
    this.opacity = 0.7,
  });

  @override
  State<EnhancedImageOverlay> createState() => _EnhancedImageOverlayState();
}

class _EnhancedImageOverlayState extends State<EnhancedImageOverlay> {
  Offset? _topLeft;
  double? _width;
  double? _height;
  Timer? _updateTimer;
  bool _hasError = false;
  bool _isImageLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadImageFromBytes();
    _startPositionUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadImageFromBytes() async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(widget.imageBytes, (result) {
        completer.complete(result);
      });
      await completer.future; // Just wait for the image to load
      if (mounted) {
        setState(() {
          _isImageLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading image from bytes: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _startPositionUpdates() {
    // Update more frequently for smoother movement
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateImagePosition();
    });
    _updateImagePosition();
  }

  Future<void> _updateImagePosition() async {
    try {
      // Get coordinates for all corners for more accurate placement
      final northWest = await widget.mapController.getScreenCoordinate(
        LatLng(widget.bounds.northeast.latitude,
            widget.bounds.southwest.longitude),
      );
      final northEast = await widget.mapController.getScreenCoordinate(
        LatLng(widget.bounds.northeast.latitude,
            widget.bounds.northeast.longitude),
      );
      final southWest = await widget.mapController.getScreenCoordinate(
        LatLng(widget.bounds.southwest.latitude,
            widget.bounds.southwest.longitude),
      );
      final southEast = await widget.mapController.getScreenCoordinate(
        LatLng(widget.bounds.southwest.latitude,
            widget.bounds.northeast.longitude),
      );

      if (mounted) {
        // Use the northwest corner as the top-left
        final topLeft = Offset(northWest.x.toDouble(), northWest.y.toDouble());

        // Calculate width and height based on the maximum dimensions
        final widthNorth = (northEast.x - northWest.x).abs().toDouble();
        final widthSouth = (southEast.x - southWest.x).abs().toDouble();
        final heightWest = (southWest.y - northWest.y).abs().toDouble();
        final heightEast = (southEast.y - northEast.y).abs().toDouble();

        // Use the largest dimensions to ensure the image covers the entire area
        final width = max(widthNorth, widthSouth);
        final height = max(heightWest, heightEast);

        setState(() {
          _topLeft = topLeft;
          _width = width;
          _height = height;
        });
      }
    } catch (e) {
      print('Error updating image position: $e');
      // Silently handle errors
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_topLeft == null ||
        _width == null ||
        _height == null ||
        !_isImageLoaded) {
      return const SizedBox.shrink();
    }

    // Filter out unreasonable values that might cause rendering issues
    if (_width! < 10 || _height! < 10 || _width! > 5000 || _height! > 5000) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _topLeft!.dx,
      top: _topLeft!.dy,
      width: _width,
      height: _height,
      child: IgnorePointer(
        child: Opacity(
          opacity: widget.opacity,
          child: _hasError
              ? _buildErrorWidget()
              : Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error displaying image: $error');
                    setState(() {
                      _hasError = true;
                    });
                    return _buildErrorWidget();
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2),
        color: Colors.red.withOpacity(0.2),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.red, size: 32),
            SizedBox(height: 8),
            Text(
              'Image could not be displayed',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
