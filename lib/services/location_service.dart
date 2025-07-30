import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Optimized real-time location service for tracking user movement
class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Location tracking state
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  LatLng? _currentLatLng;
  bool _isTracking = false;
  bool _hasPermission = false;

  // Location accuracy and update settings
  LocationAccuracy _desiredAccuracy = LocationAccuracy.high;
  double _distanceFilter = 1.0; // Update every 1 meter for smooth tracking
  Duration _timeInterval = const Duration(milliseconds: 500); // 500ms updates

  // Callback management
  final List<Function(Position)> _locationUpdateCallbacks = [];
  final List<Function(LatLng)> _latLngUpdateCallbacks = [];

  // Movement detection
  Position? _lastPosition;
  double _movementThreshold = 0.5; // meters
  bool _isMoving = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  LatLng? get currentLatLng => _currentLatLng;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;
  bool get isMoving => _isMoving;

  /// Initialize the location service
  Future<bool> initialize() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return false;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return false;
      }

      _hasPermission = true;

      // Get initial position
      await _updateCurrentPosition();

      debugPrint('LocationService initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing LocationService: $e');
      return false;
    }
  }

  /// Start real-time location tracking
  Future<bool> startTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    double distanceFilter = 1.0,
    Duration timeInterval = const Duration(milliseconds: 500),
  }) async {
    if (_isTracking) {
      debugPrint('Location tracking is already active');
      return true;
    }

    if (!_hasPermission) {
      bool initialized = await initialize();
      if (!initialized) return false;
    }

    _desiredAccuracy = accuracy;
    _distanceFilter = distanceFilter;
    _timeInterval = timeInterval;

    try {
      // Configure location settings for optimal real-time tracking
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // Get all updates, we'll filter manually
        timeLimit: Duration(seconds: 10), // Timeout for each location request
      );

      // Start position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _handleLocationUpdate,
        onError: _handleLocationError,
        cancelOnError: false,
      );

      _isTracking = true;
      debugPrint('Real-time location tracking started');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  void stopTracking() {
    if (!_isTracking) return;

    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    _isMoving = false;
    _lastPosition = null;

    debugPrint('Location tracking stopped');
    notifyListeners();
  }

  /// Handle location updates with optimizations
  void _handleLocationUpdate(Position position) {
    // Skip updates that don't meet our criteria
    if (!_shouldProcessUpdate(position)) {
      return;
    }

    _currentPosition = position;
    _currentLatLng = LatLng(position.latitude, position.longitude);

    // Detect movement
    _detectMovement(position);

    // Notify all listeners
    _notifyLocationUpdate(position);
    _notifyLatLngUpdate(_currentLatLng!);
    notifyListeners();
  }

  /// Determine if we should process this location update
  bool _shouldProcessUpdate(Position position) {
    if (_currentPosition == null) return true;

    // Calculate distance from last position
    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Only process if moved enough distance or accuracy improved significantly
    if (distance < _distanceFilter &&
        position.accuracy >= _currentPosition!.accuracy) {
      return false;
    }

    // Check time interval (optional additional filter)
    if (_currentPosition!.timestamp != null && position.timestamp != null) {
      Duration timeDiff =
          position.timestamp!.difference(_currentPosition!.timestamp!);
      if (timeDiff < _timeInterval && distance < _distanceFilter * 2) {
        return false;
      }
    }

    return true;
  }

  /// Detect if user is moving
  void _detectMovement(Position position) {
    if (_lastPosition == null) {
      _lastPosition = position;
      return;
    }

    double distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Consider movement if distance > threshold and reasonable speed
    double speed = position.speed; // m/s
    bool wasMoving = _isMoving;

    _isMoving =
        distance > _movementThreshold && speed > 0.5; // 0.5 m/s ≈ walking pace

    // Notify if movement status changed
    if (_isMoving != wasMoving) {
      debugPrint(
          'Movement status changed: ${_isMoving ? "Moving" : "Stationary"}');
    }

    _lastPosition = position;
  }

  /// Handle location errors
  void _handleLocationError(dynamic error) {
    debugPrint('Location tracking error: $error');
    // Don't stop tracking on errors, just log them
  }

  /// Update current position manually (one-time)
  Future<Position?> _updateCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: _desiredAccuracy,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _currentLatLng = LatLng(position.latitude, position.longitude);
      notifyListeners();

      return position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Get current position (public method)
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    if (!_hasPermission) {
      bool initialized = await initialize();
      if (!initialized) return null;
    }

    return await _updateCurrentPosition();
  }

  /// Add callback for position updates
  void addLocationUpdateCallback(Function(Position) callback) {
    if (!_locationUpdateCallbacks.contains(callback)) {
      _locationUpdateCallbacks.add(callback);
    }
  }

  /// Remove callback for position updates
  void removeLocationUpdateCallback(Function(Position) callback) {
    _locationUpdateCallbacks.remove(callback);
  }

  /// Add callback for LatLng updates
  void addLatLngUpdateCallback(Function(LatLng) callback) {
    if (!_latLngUpdateCallbacks.contains(callback)) {
      _latLngUpdateCallbacks.add(callback);
    }
  }

  /// Remove callback for LatLng updates
  void removeLatLngUpdateCallback(Function(LatLng) callback) {
    _latLngUpdateCallbacks.remove(callback);
  }

  /// Notify position update callbacks
  void _notifyLocationUpdate(Position position) {
    for (var callback in _locationUpdateCallbacks) {
      try {
        callback(position);
      } catch (e) {
        debugPrint('Error in location update callback: $e');
      }
    }
  }

  /// Notify LatLng update callbacks
  void _notifyLatLngUpdate(LatLng latLng) {
    for (var callback in _latLngUpdateCallbacks) {
      try {
        callback(latLng);
      } catch (e) {
        debugPrint('Error in LatLng update callback: $e');
      }
    }
  }

  /// Calculate distance between two positions
  double calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  /// Calculate distance from current position to a LatLng
  double? distanceToPoint(LatLng point) {
    if (_currentPosition == null) return null;

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      point.latitude,
      point.longitude,
    );
  }

  /// Check if user is within a certain radius of a point
  bool isWithinRadius(LatLng point, double radiusMeters) {
    double? distance = distanceToPoint(point);
    return distance != null && distance <= radiusMeters;
  }

  /// Get location accuracy description
  String getAccuracyDescription() {
    if (_currentPosition == null) return 'Unknown';

    double accuracy = _currentPosition!.accuracy;
    if (accuracy <= 5) return 'Excellent (${accuracy.toStringAsFixed(1)}m)';
    if (accuracy <= 10) return 'Good (${accuracy.toStringAsFixed(1)}m)';
    if (accuracy <= 20) return 'Fair (${accuracy.toStringAsFixed(1)}m)';
    return 'Poor (${accuracy.toStringAsFixed(1)}m)';
  }

  /// Dispose resources
  @override
  void dispose() {
    stopTracking();
    _locationUpdateCallbacks.clear();
    _latLngUpdateCallbacks.clear();
    super.dispose();
  }

  /// Configure tracking parameters on the fly
  void updateTrackingSettings({
    LocationAccuracy? accuracy,
    double? distanceFilter,
    Duration? timeInterval,
    double? movementThreshold,
  }) {
    bool needsRestart = _isTracking;

    if (needsRestart) stopTracking();

    if (accuracy != null) _desiredAccuracy = accuracy;
    if (distanceFilter != null) _distanceFilter = distanceFilter;
    if (timeInterval != null) _timeInterval = timeInterval;
    if (movementThreshold != null) _movementThreshold = movementThreshold;

    if (needsRestart) {
      startTracking(
        accuracy: _desiredAccuracy,
        distanceFilter: _distanceFilter,
        timeInterval: _timeInterval,
      );
    }

    debugPrint('Location tracking settings updated');
  }

  /// Get tracking statistics
  Map<String, dynamic> getTrackingStats() {
    return {
      'isTracking': _isTracking,
      'hasPermission': _hasPermission,
      'isMoving': _isMoving,
      'currentAccuracy': _currentPosition?.accuracy ?? 0,
      'currentSpeed': _currentPosition?.speed ?? 0,
      'distanceFilter': _distanceFilter,
      'timeInterval': _timeInterval.inMilliseconds,
      'callbackCount':
          _locationUpdateCallbacks.length + _latLngUpdateCallbacks.length,
    };
  }
}
