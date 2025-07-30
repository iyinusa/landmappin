import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Extension to integrate LocationService with navigation controllers
mixin LocationServiceMixin<T extends StatefulWidget> on State<T> {
  LocationService? _locationService;
  bool _isLocationServiceActive = false;

  /// Get the location service instance
  LocationService get locationService {
    _locationService ??= LocationService();
    return _locationService!;
  }

  /// Initialize location service for this widget
  Future<bool> initializeLocationService() async {
    if (_isLocationServiceActive) return true;

    bool success = await locationService.initialize();
    if (success) {
      _isLocationServiceActive = true;
      _setupLocationCallbacks();
    }
    return success;
  }

  /// Setup location update callbacks
  void _setupLocationCallbacks() {
    locationService.addLocationUpdateCallback(_onLocationUpdate);
    locationService.addLatLngUpdateCallback(_onLatLngUpdate);
  }

  /// Handle position updates
  void _onLocationUpdate(Position position) {
    if (mounted) {
      onLocationUpdate(position);
    }
  }

  /// Handle LatLng updates
  void _onLatLngUpdate(LatLng latLng) {
    if (mounted) {
      onLatLngUpdate(latLng);
    }
  }

  /// Override this method to handle location updates
  void onLocationUpdate(Position position) {
    // Default implementation - override in your widget
  }

  /// Override this method to handle LatLng updates
  void onLatLngUpdate(LatLng latLng) {
    // Default implementation - override in your widget
  }

  /// Start real-time tracking
  Future<bool> startRealTimeTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    double distanceFilter = 1.0,
    Duration updateInterval = const Duration(milliseconds: 500),
  }) async {
    if (!_isLocationServiceActive) {
      bool initialized = await initializeLocationService();
      if (!initialized) return false;
    }

    return await locationService.startTracking(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeInterval: updateInterval,
    );
  }

  /// Stop real-time tracking
  void stopRealTimeTracking() {
    if (_isLocationServiceActive) {
      locationService.stopTracking();
    }
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    if (!_isLocationServiceActive) {
      bool initialized = await initializeLocationService();
      if (!initialized) return null;
    }

    return await locationService.getCurrentPosition();
  }

  /// Check if user is near a point
  bool isUserNearPoint(LatLng point, double radiusMeters) {
    return locationService.isWithinRadius(point, radiusMeters);
  }

  /// Get distance to a point
  double? getDistanceToPoint(LatLng point) {
    return locationService.distanceToPoint(point);
  }

  /// Cleanup location service
  @override
  void dispose() {
    if (_isLocationServiceActive && _locationService != null) {
      _locationService!.removeLocationUpdateCallback(_onLocationUpdate);
      _locationService!.removeLatLngUpdateCallback(_onLatLngUpdate);
    }
    super.dispose();
  }
}

/// Widget wrapper for easy location service integration
class LocationAwareWidget extends StatefulWidget {
  final Widget child;
  final Function(Position)? onLocationUpdate;
  final Function(LatLng)? onLatLngUpdate;
  final bool startTrackingImmediately;
  final LocationAccuracy accuracy;
  final double distanceFilter;
  final Duration updateInterval;

  const LocationAwareWidget({
    super.key,
    required this.child,
    this.onLocationUpdate,
    this.onLatLngUpdate,
    this.startTrackingImmediately = false,
    this.accuracy = LocationAccuracy.high,
    this.distanceFilter = 1.0,
    this.updateInterval = const Duration(milliseconds: 500),
  });

  @override
  State<LocationAwareWidget> createState() => _LocationAwareWidgetState();
}

class _LocationAwareWidgetState extends State<LocationAwareWidget>
    with LocationServiceMixin {
  @override
  void initState() {
    super.initState();
    if (widget.startTrackingImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startRealTimeTracking(
          accuracy: widget.accuracy,
          distanceFilter: widget.distanceFilter,
          updateInterval: widget.updateInterval,
        );
      });
    }
  }

  @override
  void onLocationUpdate(Position position) {
    widget.onLocationUpdate?.call(position);
  }

  @override
  void onLatLngUpdate(LatLng latLng) {
    widget.onLatLngUpdate?.call(latLng);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// StreamBuilder-like widget for location updates
class LocationStreamBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, AsyncSnapshot<Position> snapshot)
      builder;
  final bool startImmediately;
  final LocationAccuracy accuracy;
  final double distanceFilter;

  const LocationStreamBuilder({
    super.key,
    required this.builder,
    this.startImmediately = true,
    this.accuracy = LocationAccuracy.high,
    this.distanceFilter = 1.0,
  });

  @override
  State<LocationStreamBuilder> createState() => _LocationStreamBuilderState();
}

class _LocationStreamBuilderState extends State<LocationStreamBuilder>
    with LocationServiceMixin {
  Position? _currentPosition;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.startImmediately) {
      _initializeAndStart();
    }
  }

  Future<void> _initializeAndStart() async {
    bool success = await startRealTimeTracking(
      accuracy: widget.accuracy,
      distanceFilter: widget.distanceFilter,
    );

    if (!success) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void onLocationUpdate(Position position) {
    setState(() {
      _currentPosition = position;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    AsyncSnapshot<Position> snapshot;

    if (_hasError) {
      snapshot = AsyncSnapshot.withError(
        ConnectionState.done,
        'Failed to get location',
      );
    } else if (_currentPosition != null) {
      snapshot = AsyncSnapshot.withData(
        ConnectionState.active,
        _currentPosition!,
      );
    } else {
      snapshot = const AsyncSnapshot.waiting();
    }

    return widget.builder(context, snapshot);
  }
}
