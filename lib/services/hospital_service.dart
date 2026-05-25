import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/hospital.dart';

class HospitalService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const String _ipApiUrl = 'http://ip-api.com/json/?fields=status,lat,lon,city,regionName,country';

  // 1. IP-based Location Detection
  Future<Map<String, dynamic>> detectLocationByIp() async {
    try {
      final response = await http.get(Uri.parse(_ipApiUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          return {
            'lat': (data['lat'] as num).toDouble(),
            'lng': (data['lon'] as num).toDouble(),
            'city': data['city']?.toString() ?? 'Your Location',
            'region': data['regionName']?.toString() ?? '',
          };
        }
      }
      throw Exception('Failed to detect approximate location.');
    } catch (_) {
      // Fallback coordinates (e.g. default center)
      return {
        'lat': 12.9716, // Bangalore default
        'lng': 77.5946,
        'city': 'Bengaluru',
        'region': 'Karnataka',
      };
    }
  }

  // 2. Geocode custom city query (Nominatim OSM Geocoder)
  Future<Map<String, dynamic>?> geocodeCity(String query) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final response = await http.get(
        url,
        headers: {'User-Agent': 'health_symptom_checker_app'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final first = data[0] as Map<String, dynamic>;
          return {
            'lat': double.parse(first['lat'].toString()),
            'lng': double.parse(first['lon'].toString()),
            'city': first['display_name']?.toString().split(',')[0] ?? query,
            'region': '',
          };
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  // 3. Fetch hospitals near coordinates (OpenStreetMap Overpass API)
  Future<List<Hospital>> fetchNearbyHospitals(double lat, double lng) async {
    const int radius = 5000; // 5km search radius
    final query = '''
      [out:json][timeout:25];
      (
        node["amenity"="hospital"](around:$radius,$lat,$lng);
        node["amenity"="clinic"](around:$radius,$lat,$lng);
        node["amenity"="doctors"](around:$radius,$lat,$lng);
        way["amenity"="hospital"](around:$radius,$lat,$lng);
        way["amenity"="clinic"](around:$radius,$lat,$lng);
      );
      out center 30;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: query,
        headers: {'Content-Type': 'text/plain'},
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> elements = data['elements'] as List<dynamic>? ?? [];

        final List<Hospital> hospitals = [];
        for (var el in elements) {
          final elMap = el as Map<String, dynamic>;
          final hLat = (elMap['lat'] ?? elMap['center']?['lat'] as num?)?.toDouble();
          final hLng = (elMap['lon'] ?? elMap['center']?['lon'] as num?)?.toDouble();

          if (hLat != null && hLng != null) {
            final dist = _haversineDistance(lat, lng, hLat, hLng);
            hospitals.add(Hospital.fromJson(elMap, lat, lng, dist));
          }
        }

        // Sort by distance and limit to top 15 results
        hospitals.sort((a, b) => a.distance.compareTo(b.distance));
        return hospitals.take(15).toList();
      } else {
        throw Exception('Overpass server responded with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Overpass query error: $e');
      rethrow;
    }
  }

  // Haversine Distance Formula (Returns meters)
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371000; // Earth's radius in meters
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double dPhi = (lat2 - lat1) * pi / 180;
    final double dLambda = (lng2 - lng1) * pi / 180;

    final double a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }
}
