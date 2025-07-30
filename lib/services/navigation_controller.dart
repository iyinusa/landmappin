import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/directions_service.dart';
import '../services/location_service.dart';

/// Navigation state enum
enum NavigationState {
  idle,
  loading,
  navigating,
  finished,
  error,
}

/// Controller for managing real-time navigation
class NavigationController extends ChangeNotifier {
  // Navigation state
  NavigationState _state = NavigationState.idle;
  NavigationState get state => _state;

  // Current location
  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  // Destination
  LatLng? _destination;
  LatLng? get destination => _destination;

  // Directions data
  DirectionsResult? _directions;
  DirectionsResult? get directions => _directions;

  // Current step in navigation
  int _currentStepIndex = 0;
  int get currentStepIndex => _currentStepIndex;
  DirectionStep? get currentStep =>
      _directions != null && _currentStepIndex < _directions!.steps.length
          ? _directions!.steps[_currentStepIndex]
          : null;

  // Distance to next turn
  double _distanceToNextTurn = 0;
  double get distanceToNextTurn => _distanceToNextTurn;

  // Remaining distance and time
  String _remainingDistance = '';
  String get remainingDistance => _remainingDistance;

  String _remainingTime = '';
  String get remainingTime => _remainingTime;

  // Location tracking - using optimized LocationService
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;

  // Error message
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  /// Set the map controller
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Start navigation to a destination
  Future<void> startNavigation(LatLng destination) async {
    try {
      _setState(NavigationState.loading);
      _destination = destination;
      _errorMessage = '';

      // Initialize location service
      bool locationServiceReady = await _locationService.initialize();
      if (!locationServiceReady) {
        _setError('Unable to initialize location service');
        return;
      }

      // Get current location
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        _setError('======= Unable to get current location =======');
        return;
      }

      _currentLocation = LatLng(position.latitude, position.longitude);

      // Get directions
      final directions = await DirectionsService.getDirections(
        origin: _currentLocation!,
        destination: destination,
      );

      if (directions == null) {
        _setError('======= Unable to get directions =======');
        return;
      }

      _directions = directions;
      _currentStepIndex = 0;
      _calculateRemainingDistanceAndTime();

      // Start real-time location tracking
      _startLocationTracking();

      _setState(NavigationState.navigating);
    } catch (e) {
      _setError('Navigation error: $e');
    }
  }

  /// Stop navigation
  void stopNavigation() {
    _locationService.stopTracking();
    _locationService.removeLatLngUpdateCallback(_onLocationUpdate);
    _directions = null;
    _destination = null;
    _currentStepIndex = 0;
    _distanceToNextTurn = 0;
    _remainingDistance = '';
    _remainingTime = '';
    _setState(NavigationState.idle);
  }

  /// Start tracking user's location using optimized LocationService
  void _startLocationTracking() {
    // Setup callback for location updates
    _locationService.addLatLngUpdateCallback(_onLocationUpdate);

    // Start real-time tracking with optimal settings for navigation
    _locationService.startTracking(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2.0, // Update every 2 meters for smooth navigation
      timeInterval: const Duration(milliseconds: 500), // 500ms updates
    );
  }

  /// Handle location updates from LocationService
  void _onLocationUpdate(LatLng newLocation) {
    _updateLocation(newLocation);
  }

  /// Update user's current location
  void _updateLocation(LatLng newLocation) {
    _currentLocation = newLocation;

    if (_directions != null) {
      // Update camera position
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newLocation),
      );

      // Check if we've reached the next turn
      _checkForNextStep();

      // Update remaining distance and time
      _calculateRemainingDistanceAndTime();
    }

    notifyListeners();
  }

  /// Check if user has reached the next navigation step
  void _checkForNextStep() {
    if (_directions == null || _currentLocation == null) return;

    final currentStep = this.currentStep;
    if (currentStep == null) return;

    // Calculate distance to the end of current step
    final distanceToStepEnd = DirectionsService.calculateDistance(
      _currentLocation!,
      currentStep.endLocation,
    );

    _distanceToNextTurn = distanceToStepEnd;

    // If we're close to the step end (within 20 meters), move to next step
    if (distanceToStepEnd < 20 &&
        _currentStepIndex < _directions!.steps.length - 1) {
      _currentStepIndex++;
      notifyListeners();
    }

    // Check if we've reached the final destination
    final distanceToDestination = DirectionsService.calculateDistance(
      _currentLocation!,
      _destination!,
    );

    if (distanceToDestination < 20) {
      _setState(NavigationState.finished);
    }
  }

  /// Calculate remaining distance and time
  void _calculateRemainingDistanceAndTime() {
    if (_directions == null || _currentLocation == null) return;

    double totalRemainingDistance = 0;
    int totalRemainingTime = 0; // in seconds

    // Add distance from current location to end of current step
    if (currentStep != null) {
      totalRemainingDistance += DirectionsService.calculateDistance(
        _currentLocation!,
        currentStep!.endLocation,
      );
    }

    // Add distance from remaining steps
    for (int i = _currentStepIndex + 1; i < _directions!.steps.length; i++) {
      final step = _directions!.steps[i];
      for (int j = 0; j < step.polylinePoints.length - 1; j++) {
        totalRemainingDistance += DirectionsService.calculateDistance(
          step.polylinePoints[j],
          step.polylinePoints[j + 1],
        );
      }
    }

    // Convert distance to readable format
    if (totalRemainingDistance > 1000) {
      _remainingDistance =
          '${(totalRemainingDistance / 1000).toStringAsFixed(1)} km';
    } else {
      _remainingDistance = '${totalRemainingDistance.round()} m';
    }

    // Estimate remaining time (assuming 5 km/h walking speed)
    totalRemainingTime =
        (totalRemainingDistance / 1.39).round(); // 5 km/h = 1.39 m/s

    if (totalRemainingTime > 3600) {
      final hours = totalRemainingTime ~/ 3600;
      final minutes = (totalRemainingTime % 3600) ~/ 60;
      _remainingTime = '${hours}h ${minutes}m';
    } else if (totalRemainingTime > 60) {
      final minutes = totalRemainingTime ~/ 60;
      _remainingTime = '${minutes}m';
    } else {
      _remainingTime = '${totalRemainingTime}s';
    }
  }

  /// Set navigation state
  void _setState(NavigationState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Set error state
  void _setError(String message) {
    _errorMessage = message;
    _setState(NavigationState.error);
  }

  /// Get polyline for the route
  Polyline? get routePolyline {
    if (_directions == null) return null;

    return Polyline(
      polylineId: const PolylineId('route'),
      points: _directions!.polylinePoints,
      color: Colors.blue,
      width: 5,
      patterns: [],
    );
  }

  /// Get markers for navigation
  Set<Marker> get navigationMarkers {
    final markers = <Marker>{};

    // Current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Destination marker
    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    return markers;
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _locationService.removeLatLngUpdateCallback(_onLocationUpdate);
    super.dispose();
  }
}
