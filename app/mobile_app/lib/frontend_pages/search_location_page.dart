import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:latlong2/latlong.dart';
import '../Maps/ui/maps_navigation_screen.dart';
import '../frontend_models/location_model.dart';
import '../frontend_services/osm_service.dart';
import '../frontend_theme/app_theme.dart';
import '../frontend_widgets/location_card.dart';



class SearchLocationPage extends StatefulWidget {
  const SearchLocationPage({super.key});

  @override
  State<SearchLocationPage> createState() => _SearchLocationPageState();
}

class _SearchLocationPageState extends State<SearchLocationPage> {
  final OSMService _osmService = OSMService();
  final TextEditingController _searchController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<LocationModel> _searchResults = [];
  bool _isListening = false;
  bool _isSearching = false;
  bool _speechAvailable = false;
  bool _preferDetection = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (mounted) {
      setState(() => _speechAvailable = available);
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _searchController.text = result.recognizedWords;
        });

        if (result.finalResult) {
          final spoken = result.recognizedWords.toLowerCase();
          _preferDetection = spoken.contains("with detection") ||
              spoken.contains("with object detection") ||
              spoken.contains("obstacle detection");

          _searchLocations();
        }

        // if (result.finalResult) {
        //   setState(() => _isListening = false);
        //
        //   SemanticsService.announce(
        //     'Search query: ${result.recognizedWords}',
        //     TextDirection.ltr,
        //   );
        //
        //   // Auto-search on voice complete
        //   _searchLocations();
        // }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _searchLocations() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search query')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await _osmService.searchLocations(query, limit: 10);

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No locations found for "$query"')),
        );

        SemanticsService.announce(
          'No locations found for $query',
          TextDirection.ltr,
        );
      } else {
        SemanticsService.announce(
          'Found ${results.length} locations. Select one to start navigation.',
          TextDirection.ltr,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSearching = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: ${e.toString()}')),
      );
    }
  }

  void _startNavigation(LocationModel location) {
    final dest = LatLng(location.latitude, location.longitude);

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
                    Navigator.of(context).push(
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
                    Navigator.of(context).push(
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

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Location'),
        leading: Semantics(
          label: 'Back button. Double tap to go back.',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      backgroundColor: AppTheme.backgroundLight,
      body: Column(
        children: [
          // Search Input Section
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              boxShadow: AppTheme.softShadow,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Semantics(
                  label: 'Search location input field. Enter location to search.',
                  textField: true,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Enter location',
                      hintText: 'Say or type location name',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppTheme.primaryBlue),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(AppTheme.radiusM),
                         borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(AppTheme.radiusM),
                         borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                      ),
                      suffixIcon: _isListening
                          ? IconButton(
                        icon: Icon(Icons.mic, color: AppTheme.primaryGreen),
                        onPressed: _stopListening,
                        tooltip: 'Stop listening',
                      )
                          : IconButton(
                        icon: Icon(Icons.mic, color: AppTheme.textSecondary),
                        onPressed: _startListening,
                        tooltip: 'Start voice input',
                      ),
                    ),
                    onSubmitted: (_) => _searchLocations(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Search button. Double tap to search for locations.',
                        button: true,
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : _searchLocations,
                          icon: _isSearching
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Icon(Icons.search),
                          label: Text(_isSearching ? 'Searching...' : 'Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue, // Primary Action
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label: _isListening
                          ? 'Stop listening button. Double tap to stop voice input.'
                          : 'Start voice input button. Double tap to speak your search query.',
                      button: true,
                      child: ElevatedButton.icon(
                        onPressed: _isListening ? _stopListening : _startListening,
                        icon: Icon(_isListening ? Icons.stop : Icons.mic),
                        label: Text(_isListening ? 'Stop' : 'Voice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening ? AppTheme.primaryGreen : Colors.white,
                          foregroundColor: _isListening ? Colors.white : AppTheme.primaryBlue,
                          side: _isListening ? null : BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          elevation: _isListening ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, color: AppTheme.primaryGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Listening... Speak now',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Results Section
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Search for locations',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use voice input or type to search for locations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return LocationCard(
                  location: _searchResults[index],
                  onTap: () {
                    if (_preferDetection) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MapsNavigation(
                            destination: LatLng(_searchResults[index].latitude, _searchResults[index].longitude),
                            withDetection: true,
                          ),
                        ),
                      );
                    } else {
                      _startNavigation(_searchResults[index]); // shows sheet
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
