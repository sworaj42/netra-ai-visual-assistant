import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../frontend_models/location_model.dart';
import '../frontend_services/location_service.dart';
import '../Maps/ui/maps_navigation_screen.dart';
import '../frontend_theme/app_theme.dart';
import '../frontend_widgets/location_card.dart';

class LocationsListPage extends StatefulWidget {
  final String category;

  const LocationsListPage({
    super.key,
    required this.category,
  });

  @override
  State<LocationsListPage> createState() => _LocationsListPageState();
}

class _LocationsListPageState extends State<LocationsListPage> {
  final LocationService _locationService = LocationService();
  List<LocationModel> _locations = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  void _showNavigationModeSheet(LatLng dest) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Start Navigation",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text("Navigation only"),
                  subtitle: const Text("Map + route + voice guidance"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapsNavigation(
                          destination: dest,
                          withDetection: false,
                        ),
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text("Navigation + Object Detection"),
                  subtitle: const Text("Map + route + live obstacle detection"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapsNavigation(
                          destination: dest,
                          withDetection: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get current position
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      // Get nearby places
      final places = await _locationService.getNearbyPlaces(
        latitude: position!.latitude,
        longitude: position.longitude,
        category: widget.category,
        limit: 10, // Increased limit slightly
        radius: 2000, // 2km radius
      );

      setState(() {
        _locations = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _getCategoryTitle() {
    switch (widget.category.toUpperCase()) {
      case 'TRANSPORT':
        return 'Nearby Transport';
      case 'HEALTH':
        return 'Health Services';
      case 'BANK AND ATM':
        return 'Banks & ATMs';
      case 'FOOD':
        return 'Restaurants';
      case 'LODGING':
        return 'Hotels';
      case 'STORE':
        return 'Stores';
      default:
        return 'Nearby Places';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Semantics(
          sortKey: OrdinalSortKey(0.0),
          header: true,
          child: Text(_getCategoryTitle()),
        ),
        centerTitle: true,
        leading: Semantics(
          sortKey: OrdinalSortKey(1.0),
          label: 'Back button. Double tap to return to categories.',
          button: true,
          excludeSemantics: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new), // Modern icon
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          Semantics(
            sortKey: OrdinalSortKey(2.0),
            label: 'Refresh locations. Double tap to reload list.',
            button: true,
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchLocations,
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Locations',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchLocations,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: AppTheme.dividerColor),
            const SizedBox(height: 16),
            Text(
              'No Places Found',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.textSecondary),
            ),
             const SizedBox(height: 8),
             Text(
              'No ${widget.category.toLowerCase()} found nearby.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final loc = _locations[index];
        
        // Manual staggered animation
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 600)), // Staggered delay caps at 1s
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: LocationCard(
            location: loc,
            onTap: () {
              final dest = LatLng(loc.latitude, loc.longitude);
              _showNavigationModeSheet(dest);
            },
          ),
        );
      },
    );
  }
}
