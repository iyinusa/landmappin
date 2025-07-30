import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/map_project.dart';
import '../models/map_point.dart';
import '../db/hive_boxes.dart';
import '../widgets/map_loading_widget.dart';
import '../widgets/animated_dialog.dart';
import '../widgets/navigation_panel.dart';
import '../services/navigation_controller.dart';

class MapViewPage extends StatefulWidget {
  final MapProject project;

  const MapViewPage({super.key, required this.project});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  GoogleMapController? _controller;
  Position? _currentPosition;
  List<MapPoint> _points = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String? _errorMessage;
  MapType _currentMapType = MapType.normal; // Add map type state

  // Navigation controller
  late NavigationController _navigationController;

  @override
  void initState() {
    super.initState();
    _navigationController = NavigationController();
    _initializeMap();
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      // Get current location
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Load map points
      await _loadMapPoints();

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

  Future<void> _loadMapPoints() async {
    final box = HiveBoxes.getMapPointsBox();
    final projectPoints = box.values
        .where((point) => point.projectId == widget.project.id)
        .toList();

    _points = projectPoints;
    _createMarkers();
  }

  void _createMarkers() {
    Set<Marker> projectMarkers = _points
        .map((point) => Marker(
              markerId: MarkerId('point_${point.label}'),
              position: LatLng(point.lat, point.lng),
              infoWindow: InfoWindow(
                title: point.label,
                snippet:
                    'Lat: ${point.lat.toStringAsFixed(6)}, Lng: ${point.lng.toStringAsFixed(6)}',
                onTap: () => _showPointDetails(point),
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
            ))
        .toSet();

    // Add current location marker if available
    if (_currentPosition != null) {
      projectMarkers.add(Marker(
        markerId: const MarkerId('current_location'),
        position:
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    // Combine project markers with navigation markers
    _markers = {...projectMarkers, ..._navigationController.navigationMarkers};

    // Update polylines
    _polylines = {};
    if (_navigationController.routePolyline != null) {
      _polylines.add(_navigationController.routePolyline!);
    }
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
                const Icon(Icons.location_on, color: Colors.red, size: 28),
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
                '${_calculateDistance(_currentPosition!, LatLng(point.lat, point.lng)).toStringAsFixed(0)}m',
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

  double _calculateDistance(Position from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  void _navigateToPoint(MapPoint point) {
    Navigator.pop(context);

    // Start navigation
    final destination = LatLng(point.lat, point.lng);
    _navigationController.startNavigation(destination);

    // Set up navigation controller listener
    _navigationController.addListener(_onNavigationStateChanged);
  }

  void _onNavigationStateChanged() {
    if (mounted) {
      setState(() {
        _createMarkers(); // Update markers and polylines
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _navigationController.setMapController(controller);

    // Center map on first point or current location
    if (_points.isNotEmpty) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_points.first.lat, _points.first.lng),
          15.0,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.project.name} - Map View',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showMapLegend,
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
                    const Text('Normal'),
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
                    const Text('Satellite'),
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
                    const Text('Hybrid'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? PulsingMapLoadingWidget(
              message: 'Loading map...',
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
                            : const LatLng(0, 0),
                        zoom: 15.0,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapType: _currentMapType,
                      onTap: (LatLng latLng) {
                        // Optional: Add new point on tap
                      },
                    ),
                    // Navigation panel overlay
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: NavigationPanel(
                        controller: _navigationController,
                        onStopNavigation: () {
                          _navigationController.stopNavigation();
                          setState(() {
                            _createMarkers(); // Refresh markers
                          });
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSearchDialog,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.search),
        label: const Text('Find Location'),
      ),
    );
  }

  void _changeMapType(MapType mapType) {
    setState(() {
      _currentMapType = mapType;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Map type changed to ${mapType.toString().split('.').last}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMapLegend() {
    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.map_outlined,
        color: Colors.blue,
        size: 48,
      ),
      title: const Text('Map Legend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegendItem(Icons.location_on, Colors.red, 'Project Points'),
          _buildLegendItem(Icons.my_location, Colors.blue, 'Your Location'),
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

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();

    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.search_outlined,
        color: Colors.green,
        size: 48,
      ),
      title: const Text('Search Location'),
      content: TextField(
        controller: searchController,
        decoration: const InputDecoration(
          hintText: 'Enter location name...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
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
    // Find matching points
    final matchingPoints = _points
        .where(
            (point) => point.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (matchingPoints.isNotEmpty) {
      final point = matchingPoints.first;

      // Show dialog with navigation option
      _showNavigationDialog(point);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not found')),
      );
    }
  }

  void _showNavigationDialog(MapPoint point) {
    ModernAlertDialog.show(
      context: context,
      icon: const Icon(
        Icons.location_on,
        color: Colors.green,
        size: 48,
      ),
      title: Text('Found: ${point.label}'),
      content: Text(
          'Would you like to navigate to this location or just view it on the map?'),
      actions: [
        ModernDialogButton(
          text: 'View Only',
          onPressed: () {
            Navigator.pop(context);
            _controller?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(point.lat, point.lng),
                18.0,
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Viewing: ${point.label}')),
            );
          },
        ),
        ModernDialogButton(
          text: 'Navigate',
          isPrimary: true,
          onPressed: () {
            Navigator.pop(context);
            _navigateToPoint(point);
          },
        ),
      ],
    );
  }
}
