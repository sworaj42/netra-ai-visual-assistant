import 'dart:convert';
import 'package:http/http.dart' as http;

import '../frontend_models/location_model.dart';


class OSMService {
  static const String _nominatimHost = 'nominatim.openstreetmap.org';
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String _overpassBaseUrl = 'https://overpass-api.de/api/interpreter';

  // IMPORTANT: Replace with your real email (or a project email)
  static const String _contactEmail = 'YOUR_REAL_EMAIL_HERE';

  // Use ONE consistent User-Agent everywhere.
  static String get _userAgent =>
      'Netra/1.0 (Samikshya Baniya; contact: $_contactEmail)';

  static Map<String, String> get _nominatimHeaders => {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
    'Accept-Language': 'en',
  };

  /// Reverse geocode coordinates to address
  Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      // Small delay to be kind to the server (and avoid being blocked)
      await Future.delayed(const Duration(milliseconds: 900));

      final url = Uri.https(
        _nominatimHost,
        '/reverse',
        {
          'format': 'json',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '18',
          'addressdetails': '1',
          'email': _contactEmail,
        },
      );

      final response = await http.get(url, headers: _nominatimHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final addressParts = <String>[];
          if (address['road'] != null) addressParts.add(address['road']);
          if (address['house_number'] != null) addressParts.add(address['house_number']);
          if (address['suburb'] != null) addressParts.add(address['suburb']);
          if (address['city'] != null) addressParts.add(address['city']);
          if (address['state'] != null) addressParts.add(address['state']);
          if (address['country'] != null) addressParts.add(address['country']);

          if (addressParts.isNotEmpty) return addressParts.join(', ');
        }

        if (data['display_name'] != null) {
          return data['display_name'] as String;
        }
      }

      return 'Address not found';
    } catch (e) {
      return 'Error fetching address: ${e.toString()}';
    }
  }

  /// Search for nearby places by category
  Future<List<LocationModel>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String category,
    double radius = 1000,
    int limit = 6,
  }) async {
    return await _searchWithNominatim(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radius: radius,
      limit: limit,
    );
  }

  /// Search nearby using Nominatim
  Future<List<LocationModel>> _searchWithNominatim({
    required double latitude,
    required double longitude,
    required String category,
    double radius = 1000,
    int limit = 6,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 900));

      final query = _getCategorySearchQuery(category);

      // radius meters -> degrees approx
      final degreeOffset = radius / 111000;

      final url = Uri.https(
        _nominatimHost,
        '/search',
        {
          'q': query,
          'format': 'json',
          'limit': (limit * 2).toString(),
          'bounded': '1',
          'viewbox':
          '${longitude - degreeOffset},${latitude - degreeOffset},${longitude + degreeOffset},${latitude + degreeOffset}',
          'addressdetails': '1',
          'email': _contactEmail,
        },
      );

      final response = await http.get(url, headers: _nominatimHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final places = <LocationModel>[];

        for (final item in data) {
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          if (lat == 0.0 || lon == 0.0) continue;

          final displayName = item['display_name'] as String? ?? '';
          final name = displayName.split(',').first.trim();

          places.add(
            LocationModel(
              name: name.isNotEmpty ? name : 'Unknown ${_getCategoryName(category)}',
              latitude: lat,
              longitude: lon,
              address: displayName,
              category: category,
            ),
          );
        }

        return places.take(limit).toList();
      }

      // Don’t throw here; nearby lists can gracefully show “none”.
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Search for locations by query string (Search page)
  Future<List<LocationModel>> searchLocations(String query, {int limit = 10}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    await Future.delayed(const Duration(milliseconds: 900));

    final url = Uri.https(
      _nominatimHost,
      '/search',
      {
        'q': trimmed,
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '1',
        'email': _contactEmail,
      },
    );

    final response = await http.get(url, headers: _nominatimHeaders);

    if (response.statusCode != 200) {
      // This is what your UI shows in SnackBar
      throw Exception('Nominatim search failed: ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected response from Nominatim (not a list).');
    }

    return decoded
        .map<LocationModel>((item) {
      final displayName = (item['display_name'] ?? '').toString();
      final lat = double.tryParse((item['lat'] ?? '').toString()) ?? 0.0;
      final lon = double.tryParse((item['lon'] ?? '').toString()) ?? 0.0;

      return LocationModel(
        name: displayName.isNotEmpty ? displayName.split(',').first.trim() : trimmed,
        latitude: lat,
        longitude: lon,
        address: displayName,
      );
    })
        .where((loc) => loc.latitude != 0.0 && loc.longitude != 0.0)
        .toList();
  }

  // ----- helpers -----

  String _getOSMTag(String category) {
    switch (category.toUpperCase()) {
      case 'TRANSPORT':
        return 'public_transport';
      case 'HEALTH':
        return 'amenity';
      case 'BANK AND ATM':
        return 'amenity';
      case 'FOOD':
        return 'amenity';
      case 'LODGING':
        return 'tourism';
      case 'STORE':
        return 'shop';
      default:
        return 'amenity';
    }
  }

  String _getCategorySearchQuery(String category) {
    switch (category.toUpperCase()) {
      case 'TRANSPORT':
        return 'bus stop';
      case 'HEALTH':
        return 'hospital';
      case 'BANK AND ATM':
        return 'bank';
      case 'FOOD':
        return 'restaurant';
      case 'LODGING':
        return 'hotel';
      case 'STORE':
        return 'shop';
      default:
        return category.toLowerCase();
    }
  }

  String _getCategoryName(String category) {
    switch (category.toUpperCase()) {
      case 'TRANSPORT':
        return 'Transport';
      case 'HEALTH':
        return 'Health';
      case 'BANK AND ATM':
        return 'Bank';
      case 'FOOD':
        return 'Restaurant';
      case 'LODGING':
        return 'Hotel';
      case 'STORE':
        return 'Shop';
      default:
        return 'Place';
    }
  }
}
