import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:geolocator/geolocator.dart';
import '../frontend_services/location_service.dart';
import '../frontend_theme/app_theme.dart';
import '../frontend_theme/app_theme.dart';
import '../frontend_widgets/category_button.dart';
import '../frontend_services/around_me_service.dart';
import 'locations_list_page.dart';
import 'search_location_page.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  String _locationAddress = '';
  bool _isLoading = true;

  late FocusNode _titleFocusNode;

  @override
  void initState() {
    super.initState();
    _titleFocusNode = FocusNode();
    
    // Request focus on the title after the frame renders to force TalkBack to this element
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });

    // Prioritize announcement of mode
    SemanticsService.announce(
      "Navigation Mode. Fetching current location...",
      TextDirection.ltr,
    );
    // Automatically fetch location when page opens
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _locationAddress = 'Fetching address...'; // Provide feedback
    });

    try {
      final position = await _locationService.getCurrentPosition();
      
      final address = await _locationService.getAddressFromCoordinates(
        position!.latitude,
        position.longitude,
      );

      setState(() {
        _currentPosition = position;
        _locationAddress = address;
        _isLoading = false;
      });

      // Explicit announce removed to prevent double-speak with liveRegion
    } catch (e) {
      setState(() {
        _locationAddress = 'Unable to get location';
        _isLoading = false;
      });
      _showErrorDialog('Error: ${e.toString()}');
    }
  }

  void _showLocationDialog(Position position, String address) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Current Location'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Address:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(address),
                const SizedBox(height: 16),
                const Text(
                  'Coordinates:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Latitude: ${position.latitude.toStringAsFixed(6)}'),
                Text('Longitude: ${position.longitude.toStringAsFixed(6)}'),
                const SizedBox(height: 8),
                Text('Accuracy: ${position.accuracy.toStringAsFixed(2)} meters'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToCategory(String category) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LocationsListPage(category: category),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          sortKey: const OrdinalSortKey(0.0), // Read First
          header: true,
          child: Focus(
            focusNode: _titleFocusNode,
            child: const Text('Navigation Mode'),
          ),
        ),
        leading: Semantics(
          sortKey: const OrdinalSortKey(1.0), // Read Second
          label: 'Back button. Double tap to go back to home.',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // --- TOP SECTION: LOCATION & SEARCH (Flex: 5) ---
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    // Current Location
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          label: _locationAddress.isEmpty
                              ? 'Current Location. Loading.'
                              : 'Current Location. $_locationAddress. Double tap to view details.',
                          hint: 'Shows your current geographical position and address.',
                          button: true,
                          liveRegion: true,
                          child: InkWell(
                            onTap: () {
                              if (_currentPosition != null) {
                                _showLocationDialog(_currentPosition!, _locationAddress);
                              } else {
                                _getCurrentLocation();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.charcoalGradient,
                                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'CURRENT LOCATION',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4), // Reduced height
                                          Expanded( // Allow text to take available space
                                            child: Center(
                                              child: Text(
                                                _locationAddress.isEmpty
                                                    ? 'Location not available'
                                                    : _locationAddress,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16, // Slightly reduced
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.2, // Tighter height
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Around Me
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Semantics(
                          label: 'Around Me. Double tap to hear nearby places.',
                          hint: 'Scans for hospitals, shops, and stops around you.',
                          button: true,
                          child: InkWell(
                            onTap: () {
                              AroundMeService().announceAroundMe(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.crimsonGradient,
                                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.radar,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'AROUND ME',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Search Location
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          label: 'Search and navigate to a specific location. Double tap to search.',
                          hint: 'Search and find a specific location or address.',
                          button: true,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) =>
                                      const SearchLocationPage(),
                                  transitionsBuilder:
                                      (context, animation, secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.charcoalGradient,
                                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'SEARCH FOR LOCATION',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- BOTTOM SECTION: CATEGORIES (Flex: 4) ---
              // Replacing GridView with Column of Rows for Flex fit
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // ROW 1
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CategoryButton(
                              label: 'HEALTH',
                              hint: 'Find nearby hospitals, clinics, and health services.',
                              icon: Icons.local_hospital,
                              onTap: () => _navigateToCategory('HEALTH'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CategoryButton(
                              label: 'TRANSPORT',
                              hint: 'Find nearby transportation services, bus stops, and taxi stands.',
                              icon: Icons.directions_bus,
                              onTap: () => _navigateToCategory('TRANSPORT'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CategoryButton(
                              label: 'BANK / ATM',
                              hint: 'Find nearby banks and ATM machines.',
                              icon: Icons.atm,
                              onTap: () => _navigateToCategory('BANK AND ATM'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ROW 2
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CategoryButton(
                              label: 'FOOD',
                              hint: 'Find nearby restaurants, cafes, and food services.',
                              icon: Icons.restaurant,
                              onTap: () => _navigateToCategory('FOOD'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CategoryButton(
                              label: 'LODGING',
                              hint: 'Find nearby hotels, hostels, and accommodation services.',
                              icon: Icons.hotel,
                              onTap: () => _navigateToCategory('LODGING'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CategoryButton(
                              label: 'STORE',
                              hint: 'Find nearby shops, stores, and shopping centers.',
                              icon: Icons.store,
                              onTap: () => _navigateToCategory('STORE'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
