class LocationModel {
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? category;
  double? distance; // in meters

  LocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.category,
    this.distance,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      name: json['name'] ?? json['display_name'] ?? 'Unknown',
      latitude: double.parse(json['lat']?.toString() ?? '0'),
      longitude: double.parse(json['lon']?.toString() ?? '0'),
      address: json['display_name'],
      category: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'category': category,
      'distance': distance,
    };
  }
}

