import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double? distanceMeters;
  final double? durationSeconds;

  RouteResult({
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory RouteResult.empty() {
    return RouteResult(
      points: [],
      steps: [],
      distanceMeters: null,
      durationSeconds: null,
    );
  }
}

class RouteStep {
  final String name;
  final double distance; // meters
  final double duration; // seconds
  final Maneuver maneuver;
  final String mode;

  // Simplified Model: Removed unused OSRM fields (exit, rotaryName, pronunciation etc.)
  // We only need basic instructions for walking.

  RouteStep({
    required this.name,
    required this.distance,
    required this.duration,
    required this.maneuver,
    required this.mode,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      name: json['name'] ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      maneuver: Maneuver.fromJson(json['maneuver'] ?? {}),
      mode: json['mode'] ?? '',
    );
  }
}

class Maneuver {
  final String type;
  final String modifier;
  final List<double> location; // [lon, lat]
  
  Maneuver({
    required this.type,
    required this.modifier,
    required this.location,
  });

  factory Maneuver.fromJson(Map<String, dynamic> json) {
    return Maneuver(
      type: json['type'] ?? '',
      modifier: json['modifier'] ?? '',
      location: (json['location'] as List?)?.cast<double>() ?? [0.0, 0.0],
    );
  }
  
  LatLng get latLng => LatLng(location[1], location[0]);
}
