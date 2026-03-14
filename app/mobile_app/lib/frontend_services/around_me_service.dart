import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// Represents a Point of Interest for "Around Me"
class AroundMePOI {
  final String name;
  final double lat;
  final double lon;
  final String category;
  double distanceMeters = 0.0;
  double bearingDegrees = 0.0; // Bearing from user to POI
  double relativeAngle = 0.0;  // Angle relative to user heading

  AroundMePOI({
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
  });
}

class AroundMeService {
  // Config
  static const double _searchRadiusMeters = 300.0;
  static const double _expandedRadiusMeters = 500.0; // For poor accuracy
  
  // Overpass Query Template
  // We prioritize: health, transport, finance, food, supplies
  static String _buildQuery(double lat, double lon, double radius) {
    return """
      [out:json][timeout:10];
      (
        node["amenity"~"pharmacy|hospital|clinic|police|bank|atm|restaurant|cafe|fast_food"](around:$radius,$lat,$lon);
        node["highway"="bus_stop"](around:$radius,$lat,$lon);
        node["shop"~"supermarket|convenience|mall"](around:$radius,$lat,$lon);
        node["leisure"="park"](around:$radius,$lat,$lon);
        node["tourism"~"museum|artwork|attraction"](around:$radius,$lat,$lon);
      );
      out body;
    """;
  }

  /// Main entry point: triggers the announcement
  Future<void> announceAroundMe(BuildContext context) async {
    // 1. Feedback to user
    SemanticsService.announce("Scanning around you...", TextDirection.ltr);

    try {
      // 2. Get Location
      // We rely on high accuracy for "Around Me"
      if (!await Geolocator.isLocationServiceEnabled()) {
        SemanticsService.announce("Location services are disabled.", TextDirection.ltr);
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // Warning for poor accuracy
      double radius = _searchRadiusMeters;
      if (position.accuracy > 40) {
        SemanticsService.announce("GPS signal is weak. Results may be approximate.", TextDirection.ltr);
        radius = _expandedRadiusMeters;
        // Wait a small moment so the warning is heard
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // 3. Fetch POIs
      final pois = await _fetchPOIs(position.latitude, position.longitude, radius);
      
      if (pois.isEmpty) {
        SemanticsService.announce("No major places found within ${radius.toInt()} meters.", TextDirection.ltr);
        return;
      }

      // 4. Heading & Processing
      double heading = 0.0;
      
      // If moving significantly, GPS heading is reliable
      if (position.speed > 1.5 && position.heading != 0.0) {
        heading = position.heading;
      } else {
        // Stationary or slow moving: Try Compass
        try {
          final compassEvent = await FlutterCompass.events?.first.timeout(const Duration(seconds: 2));
           // headingForCameraMode is often smoother, but 'heading' is magnetic north.
           // We need True North if possible, but magnetic is okay if we don't have declination.
           // Geolocator gives coords, we can compute true north if needed, but usually 'heading' is fine for "Around Me" approximations.
          if (compassEvent != null) {
            heading = compassEvent.heading ?? 0.0;
          } else {
            // Null compass stream
            heading = position.heading;
          }
        } catch (e) {
          // Timeout or error
          heading = position.heading;
        }
      }

      // If we still have 0.0 and speed is 0, we can't really do directions, but we'll try anyway 
      // or we could fallback. 
      // For now, we assume the compass worked or user is moving.
      
      String announcement = "";
      
      // DIRECTIONAL: Front/Right/Back/Left
      announcement = _formatDirectionalList(pois, position, heading);

      
      // 5. Speak
      SemanticsService.announce(announcement, TextDirection.ltr);

    } catch (e) {
      debugPrint("AroundMe Error: $e");
      SemanticsService.announce("Unable to scan surroundings.", TextDirection.ltr);
    }
  }

  Future<List<AroundMePOI>> _fetchPOIs(double lat, double lon, double radius) async {
    final uri = Uri.parse("https://overpass-api.de/api/interpreter");
    final body = _buildQuery(lat, lon, radius);
    
    try {
      final response = await http.post(uri, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List;
        
        final List<AroundMePOI> results = [];
        final Set<String> seenNames = {};

        for (var el in elements) {
          final tags = el['tags'];
          if (tags == null) continue;
          
          String name = tags['name'] ?? "";
          String amenity = tags['amenity'] ?? tags['shop'] ?? tags['highway'] ?? tags['leisure'] ?? "place";
          
          // Skip unnamed unless critical
          bool isCritical = ['hospital', 'police', 'bus_stop', 'pharmacy', 'clinic'].contains(amenity);
          if (name.isEmpty && !isCritical) continue;
          if (name.isEmpty) name = amenity.replaceAll('_', ' '); // fallback e.g. "bus stop"

          // Simple de-dupe
          if (seenNames.contains(name)) continue;
          seenNames.add(name);

          results.add(AroundMePOI(
            name: name,
            lat: el['lat'],
            lon: el['lon'],
            category: amenity,
          ));
        }
        return results;
      }
    } catch (e) {
      debugPrint("Overpass API Error: $e");
    }
    return [];
  }

  String _formatFallbackList(List<AroundMePOI> pois, Position userPos) {
    // 1. Calc distances
    for (var p in pois) {
      p.distanceMeters = _haversineMeters(userPos.latitude, userPos.longitude, p.lat, p.lon);
    }
    // 2. Sort by distance
    pois.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    
    // 3. Take Top 3
    final top = pois.take(3);
    if (top.isEmpty) return "Nothing found nearby.";
    
    final buffer = StringBuffer("Here are places around you: ");
    for (var p in top) {
      buffer.write("${p.name}, ${_formatDistance(p.distanceMeters)}. ");
    }
    return buffer.toString();
  }

  String _formatDirectionalList(List<AroundMePOI> pois, Position userPos, double heading) {
    // Buckets
    AroundMePOI? front, left, right, back;
    double frontScore = -1, leftScore = -1, rightScore = -1, backScore = -1;

    for (var p in pois) {
      // Geometry
      p.distanceMeters = _haversineMeters(userPos.latitude, userPos.longitude, p.lat, p.lon);
      p.bearingDegrees = _bearing(userPos.latitude, userPos.longitude, p.lat, p.lon);
      
      // Relative Angle: normalize(bearing - heading)
      double r = (p.bearingDegrees - heading);
      if (r <= -180) r += 360;
      if (r > 180) r -= 360;
      p.relativeAngle = r;
      
      // Score (Higher is better)
      // Base score: 1000 - distance (prefer closer)
      // Bonus: +200 for essentials
      bool isCritical = ['hospital', 'police', 'pharmacy', 'bank', 'atm', 'bus_stop'].contains(p.category);
      double score = (1000 - p.distanceMeters) + (isCritical ? 300 : 0);

      // Bucket assignment
      if (r >= -45 && r <= 45) { // FRONT
        if (score > frontScore) { frontScore = score; front = p; }
      } else if (r > 45 && r <= 135) { // RIGHT
        if (score > rightScore) { rightScore = score; right = p; }
      } else if (r >= -135 && r < -45) { // LEFT
        if (score > leftScore) { leftScore = score; left = p; }
      } else { // BACK
        if (score > backScore) { backScore = score; back = p; }
      }
    }

    // Build String
    final buffer = StringBuffer();
    bool spoken = false;
    
    if (front != null) {
      buffer.write("${front.name}, ${_formatDistance(front.distanceMeters)} to your front. ");
      spoken = true;
    }
    if (right != null) {
      buffer.write("${right.name}, ${_formatDistance(right.distanceMeters)} to your right. ");
      spoken = true;
    }
    if (left != null) {
      buffer.write("${left.name}, ${_formatDistance(left.distanceMeters)} to your left. ");
      spoken = true;
    }
    if (back != null) {
       buffer.write("${back.name}, ${_formatDistance(back.distanceMeters)} behind you. ");
       spoken = true;
    }

    if (!spoken) return "No major places in immediate directions.";
    return buffer.toString();
  }

  // Helpers

  String _formatDistance(double m) {
    if (m >= 1000) return "${(m/1000).toStringAsFixed(1)} kilometers";
    if (m < 20) return "nearby"; // Very close
    if (m < 100) return "${(m/5).round()*5} meters"; // round to 5
    return "${(m/10).round()*10} meters"; // round to 10
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Radius of Earth in meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final y = sin(_deg2rad(lon2 - lon1)) * cos(_deg2rad(lat2));
    final x = cos(_deg2rad(lat1)) * sin(_deg2rad(lat2)) -
        sin(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * cos(_deg2rad(lon2 - lon1));
    final brng = atan2(y, x);
    return (_rad2deg(brng) + 360) % 360;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
  double _rad2deg(double rad) => rad * (180.0 / pi);
}
