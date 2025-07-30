import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model for direction steps
class DirectionStep {
  final String instruction;
  final String distance;
  final String duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<LatLng> polylinePoints;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.polylinePoints,
  });

  factory DirectionStep.fromJson(Map<String, dynamic> json) {
    final startLat = json['start_location']['lat'];
    final startLng = json['start_location']['lng'];
    final endLat = json['end_location']['lat'];
    final endLng = json['end_location']['lng'];

    // Decode polyline points
    final polylineString = json['polyline']['points'];
    final polylinePoints = _decodePolyline(polylineString);

    return DirectionStep(
      instruction: json['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), ''),
      distance: json['distance']['text'],
      duration: json['duration']['text'],
      startLocation: LatLng(startLat, startLng),
      endLocation: LatLng(endLat, endLng),
      polylinePoints: polylinePoints,
    );
  }

  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

/// Model for complete directions
class DirectionsResult {
  final String totalDistance;
  final String totalDuration;
  final List<DirectionStep> steps;
  final List<LatLng> polylinePoints;
  final LatLng startLocation;
  final LatLng endLocation;

  DirectionsResult({
    required this.totalDistance,
    required this.totalDuration,
    required this.steps,
    required this.polylinePoints,
    required this.startLocation,
    required this.endLocation,
  });

  factory DirectionsResult.fromJson(Map<String, dynamic> json) {
    final route = json['routes'][0];
    final leg = route['legs'][0];

    final steps = (leg['steps'] as List)
        .map((step) => DirectionStep.fromJson(step))
        .toList();

    // Get all polyline points from all steps
    final allPolylinePoints = <LatLng>[];
    for (final step in steps) {
      allPolylinePoints.addAll(step.polylinePoints);
    }

    return DirectionsResult(
      totalDistance: leg['distance']['text'],
      totalDuration: leg['duration']['text'],
      steps: steps,
      polylinePoints: allPolylinePoints,
      startLocation: LatLng(
        leg['start_location']['lat'],
        leg['start_location']['lng'],
      ),
      endLocation: LatLng(
        leg['end_location']['lat'],
        leg['end_location']['lng'],
      ),
    );
  }
}

/// Service for getting directions from Google Directions API
class DirectionsService {
  // Note: In production, store this in environment variables or secure storage
  static const String _apiKey = 'AIzaSyAKlI_nlTLJ51y12AKpU8b8hIRsXwpZA14';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Get walking directions between two points
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'walking',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'mode=$mode&'
        'key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          return DirectionsResult.fromJson(data);
        } else {
          print('Directions API error: ${data['status']}');
          return null;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }

  /// Calculate distance between two points (Haversine formula)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius in meters

    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}
