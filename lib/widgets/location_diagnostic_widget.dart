import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service_mixin.dart';

/// Diagnostic widget to help debug location tracking issues
class LocationDiagnosticWidget extends StatefulWidget {
  const LocationDiagnosticWidget({super.key});

  @override
  State<LocationDiagnosticWidget> createState() =>
      _LocationDiagnosticWidgetState();
}

class _LocationDiagnosticWidgetState extends State<LocationDiagnosticWidget>
    with LocationServiceMixin {
  Position? _lastPosition;
  String _statusMessage = 'Initializing...';
  int _updateCount = 0;
  bool _isTracking = false;
  double _totalDistance = 0.0;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _startDiagnostics();
  }

  Future<void> _startDiagnostics() async {
    setState(() {
      _statusMessage = 'Starting location diagnostics...';
    });

    bool success = await startRealTimeTracking(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1.0,
      updateInterval: const Duration(milliseconds: 500),
    );

    setState(() {
      _isTracking = success;
      _statusMessage = success
          ? 'Location tracking active ✅'
          : 'Failed to start location tracking ❌';
    });
  }

  @override
  void onLocationUpdate(Position position) {
    setState(() {
      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distance;
      }

      _lastPosition = position;
      _updateCount++;
      _lastUpdateTime = DateTime.now();
      _statusMessage = 'Location updates: $_updateCount';
    });
  }

  void _stopDiagnostics() {
    stopRealTimeTracking();
    setState(() {
      _isTracking = false;
      _statusMessage = 'Location tracking stopped 🛑';
    });
  }

  void _resetDiagnostics() {
    setState(() {
      _updateCount = 0;
      _totalDistance = 0.0;
      _lastPosition = null;
      _lastUpdateTime = null;
      _statusMessage = 'Diagnostics reset 🔄';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Diagnostics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Service Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                    const SizedBox(height: 8),
                    Text('Is Tracking: ${_isTracking ? "Yes ✅" : "No ❌"}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Statistics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Updates received: $_updateCount'),
                    Text(
                        'Total distance: ${_totalDistance.toStringAsFixed(2)}m'),
                    Text(
                        'Last update: ${_lastUpdateTime?.toString() ?? "None"}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current Position Card
            if (_lastPosition != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Position',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Latitude: ${_lastPosition!.latitude.toStringAsFixed(6)}'),
                      Text(
                          'Longitude: ${_lastPosition!.longitude.toStringAsFixed(6)}'),
                      Text(
                          'Accuracy: ${_lastPosition!.accuracy.toStringAsFixed(1)}m'),
                      Text(
                          'Speed: ${_lastPosition!.speed.toStringAsFixed(2)} m/s'),
                      Text(
                          'Heading: ${_lastPosition!.heading.toStringAsFixed(1)}°'),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTracking ? null : _startDiagnostics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Tracking'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTracking ? _stopDiagnostics : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Stop Tracking'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _resetDiagnostics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
