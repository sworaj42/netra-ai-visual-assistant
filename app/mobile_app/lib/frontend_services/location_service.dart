import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../frontend_models/location_model.dart';
import 'osm_service.dart';

class LocationService {
  final OSMService _osmService = OSMService();

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get address from coordinates using OpenStreetMap
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    return await _osmService.reverseGeocode(latitude, longitude);
  }

  /// Get nearby places by category
  Future<List<LocationModel>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required String category,
    int limit = 6,
    double radius = 1000, // meters
  }) async {
    try {
      List<LocationModel> places = await _osmService.searchNearbyPlaces(
        latitude: latitude,
        longitude: longitude,
        category: category,
        radius: radius,
        limit: limit,
      );

      // Calculate distance for each place
      for (var place in places) {
        place.distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          place.latitude,
          place.longitude,
        );
      }

      // Sort by distance
      places.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));

      return places.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch nearby places: $e');
    }
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}

