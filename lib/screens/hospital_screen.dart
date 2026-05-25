import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hospital.dart';
import '../services/hospital_service.dart';
import '../utils/app_theme.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({super.key});

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  final HospitalService _hospitalService = HospitalService();
  final TextEditingController _searchController = TextEditingController();

  List<Hospital> _hospitals = [];
  bool _isLoading = true;
  String _currentCity = '';
  String _currentRegion = '';
  double _currentLat = 0.0;
  double _currentLng = 0.0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _detectAndFetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Detect location automatically via IP and fetch nearby hospitals
  Future<void> _detectAndFetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final loc = await _hospitalService.detectLocationByIp();
      _currentLat = loc['lat'] as double;
      _currentLng = loc['lng'] as double;
      _currentCity = loc['city'] as String;
      _currentRegion = loc['region'] as String;

      final results = await _hospitalService.fetchNearbyHospitals(_currentLat, _currentLng);
      setState(() {
        _hospitals = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not locate hospitals near you automatically.';
        _isLoading = false;
      });
    }
  }

  // Geocode custom query and fetch
  Future<void> _searchCustomCity() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final loc = await _hospitalService.geocodeCity(query);
      if (loc != null) {
        _currentLat = loc['lat'] as double;
        _currentLng = loc['lng'] as double;
        _currentCity = loc['city'] as String;
        _currentRegion = '';

        final results = await _hospitalService.fetchNearbyHospitals(_currentLat, _currentLng);
        setState(() {
          _hospitals = results;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Could not find any location named "$query".';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch medical centers. Check your internet.';
        _isLoading = false;
      });
    }
  }

  // Launch links
  Future<void> _launchUrlHelper(String urlStr) async {
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nearest Hospitals',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Header Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search city, state, or country...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                      onPressed: _searchCustomCity,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _searchCustomCity(),
                ),
                
                if (_currentCity.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Location Indicator Badge
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _currentRegion.isNotEmpty
                              ? 'Showing hospitals near: $_currentCity, $_currentRegion'
                              : 'Showing hospitals near: $_currentCity',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _detectAndFetch,
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Main Body Area
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage.isNotEmpty && _hospitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Location Query Failed',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _detectAndFetch,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Try Auto Detect', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hospitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_hospital_rounded, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No Medical Centers Found',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'We couldn\'t locate any hospitals or clinics within 5km of this area. Please type another city above.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hospitals.length,
      itemBuilder: (context, index) {
        final hospital = _hospitals[index];
        return _HospitalCard(
          hospital: hospital,
          distanceStr: _formatDistance(hospital.distance),
          onDirections: () => _launchUrlHelper(
            'https://www.google.com/maps/dir/?api=1&destination=${hospital.lat},${hospital.lng}',
          ),
          onCall: hospital.phone != null ? () => _launchUrlHelper('tel:${hospital.phone}') : null,
          onWebsite: hospital.website != null ? () => _launchUrlHelper(hospital.website!) : null,
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: Duration(milliseconds: index * 50))
            .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
      },
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 140, height: 16, color: Colors.grey),
                      const Spacer(),
                      Container(width: 60, height: 14, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(width: 80, height: 12, color: Colors.grey),
                      const SizedBox(width: 8),
                      Container(width: 40, height: 12, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(width: 100, height: 32, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(8))),
                      const SizedBox(width: 8),
                      Container(width: 60, height: 32, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(8))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final String distanceStr;
  final VoidCallback onDirections;
  final VoidCallback? onCall;
  final VoidCallback? onWebsite;

  const _HospitalCard({
    required this.hospital,
    required this.distanceStr,
    required this.onDirections,
    this.onCall,
    this.onWebsite,
  });

  IconData _getTypeIcon(String type) {
    if (type == 'clinic') return Icons.local_pharmacy_rounded;
    if (type == 'doctors') return Icons.person_search_rounded;
    return Icons.local_hospital_rounded;
  }

  Color _getTypeColor(String type) {
    if (type == 'clinic') return Colors.teal;
    if (type == 'doctors') return Colors.purple;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(hospital.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section (Title and Category Badge)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    hospital.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getTypeIcon(hospital.type), size: 11, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        hospital.type.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Middle section (Distance and subtitle)
            Row(
              children: [
                const Icon(Icons.directions_walk_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$distanceStr away',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action buttons row
            Row(
              children: [
                // Directions button
                ElevatedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.navigation_rounded, size: 16, color: Colors.white),
                  label: const Text('Directions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Call button
                if (onCall != null) ...[
                  IconButton(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone_rounded, color: Colors.green),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Website button
                if (onWebsite != null) ...[
                  IconButton(
                    onPressed: onWebsite,
                    icon: const Icon(Icons.language_rounded, color: Colors.blue),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
