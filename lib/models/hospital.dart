class Hospital {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type;
  final double distance; // distance in meters
  final String? phone;
  final String? website;

  Hospital({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.distance,
    this.phone,
    this.website,
  });

  factory Hospital.fromJson(Map<String, dynamic> json, double userLat, double userLng, double computedDistance) {
    return Hospital(
      id: json['id']?.toString() ?? '',
      name: json['tags']?['name']?.toString() ?? 
            json['tags']?['name:en']?.toString() ?? 
            'Unnamed Medical Facility',
      lat: (json['lat'] ?? json['center']?['lat'] as num).toDouble(),
      lng: (json['lon'] ?? json['center']?['lon'] as num).toDouble(),
      type: json['tags']?['amenity']?.toString() ?? 'hospital',
      distance: computedDistance,
      phone: json['tags']?['phone']?.toString() ?? 
             json['tags']?['contact:phone']?.toString(),
      website: json['tags']?['website']?.toString(),
    );
  }
}
