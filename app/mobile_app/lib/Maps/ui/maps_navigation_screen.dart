import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../depth_services/detect_service.dart';
import '../../frontend_theme/app_theme.dart';
import '../../tts/speaker.dart';
import '../../tts/speech_policy.dart';
import '../logic/navigation_manager.dart';


import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../frontend_theme/app_theme.dart';
import '../logic/navigation_manager.dart';


class MapsNavigation extends StatefulWidget {
  final LatLng destination;
  final bool withDetection;

  const MapsNavigation({
    super.key,
    required this.destination,
    this.withDetection = false,
  });

  @override
  State<MapsNavigation> createState() => _MapsNavigationState();
}

class _MapsNavigationState extends State<MapsNavigation> {
  final NavigationManager _manager = NavigationManager();
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  late FocusNode _titleFocusNode;

  @override
  void initState() {
    super.initState();
    _titleFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });

    _initHelper();
  }

  Future<void> _initHelper() async {
    await _manager.initLocation();
    await _manager.startNavigation(widget.destination);

    // Listen to changes to update map camera AND trigger route updates
    _manager.addListener(_onManagerUpdate);
  }

  void _onManagerUpdate() {
    if (!mounted) return;

    if (_manager.currentPosition != null && _isMapReady) {
      _mapController.move(_manager.currentPosition!, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _manager.removeListener(_onManagerUpdate);
    _manager.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _showDirectionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Detailed Directions",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _manager.steps.length + 1,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const ListTile(
                            leading: Icon(Icons.my_location, color: AppTheme.primaryBlue),
                            title: Text("Start", style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Navigating to destination"),
                          );
                        }

                        final step = _manager.steps[index - 1];
                        final isCurrent = (index - 1) == _manager.currentStepIndex;

                        final instruction = _manager.getInstruction(step);

                        IconData icon = Icons.directions;
                        final type = step.maneuver.type;
                        final mod = step.maneuver.modifier;

                        if (type == 'turn') {
                          if (mod.contains('left')) icon = Icons.turn_left;
                          else if (mod.contains('right')) icon = Icons.turn_right;
                          else if (mod.contains('straight')) icon = Icons.straight;
                          else if (mod.contains('uturn')) icon = Icons.u_turn_left;
                        } else if (type == 'arrive') {
                          icon = Icons.location_on;
                        } else if (type == 'roundabout') {
                          icon = Icons.sync;
                        } else if (type == 'merge') {
                          icon = Icons.call_merge;
                        } else if (type == 'fork') {
                          icon = Icons.alt_route;
                        } else if (type == 'depart') {
                          icon = Icons.explore;
                        }

                        return ListTile(
                          tileColor: isCurrent ? AppTheme.primaryBlue.withOpacity(0.08) : null,
                          leading: CircleAvatar(
                            backgroundColor: isCurrent ? AppTheme.primaryBlue : Colors.grey.shade200,
                            child: Icon(icon, color: isCurrent ? Colors.white : Colors.grey[700], size: 20),
                          ),
                          title: Text(
                            instruction,
                            style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                          ),
                          trailing: Text("${step.distance}m", style: const TextStyle(color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ Your existing map UI as a reusable widget
  Widget _buildMapStack() {
    return Stack(
      children: [
        // 1. Full Screen Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _manager.currentPosition!,
            initialZoom: 18,
            keepAlive: true,
            onMapReady: () {
              if (mounted) {
                setState(() {
                  _isMapReady = true;
                });
                if (_manager.currentPosition != null) {
                  _mapController.move(_manager.currentPosition!, 18);
                }
              }
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.netra.app',
              maxZoom: 20,
            ),

            // Route Line
            if (_manager.remainingPolyline.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _manager.remainingPolyline,
                    strokeWidth: 10,
                    color: const Color(0xAA1E88E5),
                  ),
                  Polyline(
                    points: _manager.remainingPolyline,
                    strokeWidth: 6,
                    color: const Color(0xFF1565C0),
                  ),
                ],
              ),

            // Markers
            MarkerLayer(
              markers: [
                Marker(
                  width: 50,
                  height: 50,
                  point: widget.destination,
                  child: const Icon(Icons.location_on, color: Colors.redAccent, size: 50),
                ),
                Marker(
                  width: 70,
                  height: 70,
                  point: _manager.currentPosition!,
                  child: Transform.rotate(
                    angle: (_manager.currentHeading * (3.14159 / 180)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.navigation, color: Color(0xFF1565C0), size: 40),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // 2. Top Navigation Instruction Card
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 16,
          right: 16,
          child: Semantics(
            // liveRegion removed to prevent non-stop TalkBack announcements
            label: _manager.bannerText,
            child: GestureDetector(
              onTap: _showDirectionsSheet,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _manager.bannerText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (_manager.remainingMeters != null)
                            Row(
                              children: [
                                const Icon(Icons.directions_car, color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "${(_manager.remainingMeters! / 1000).toStringAsFixed(1)} km to go",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (_manager.isRouting)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.turn_right, color: Colors.white, size: 32),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 3. Floating Re-center Button
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          right: 20,
          child: Semantics(
            label: 'Re-center map on my location',
            button: true,
            child: FloatingActionButton(
              heroTag: "recenter_btn",
              backgroundColor: AppTheme.surfaceWhite,
              foregroundColor: AppTheme.textPrimary,
              onPressed: () {
                if (_manager.currentPosition != null && _isMapReady) {
                  _mapController.move(_manager.currentPosition!, 18);
                  _mapController.rotate(-_manager.currentHeading);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ),

        // 4. List Button
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 90,
          right: 20,
          child: Semantics(
            label: 'Show detailed directions list',
            button: true,
            child: FloatingActionButton.small(
              heroTag: "list_btn",
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onPressed: _showDirectionsSheet,
              child: const Icon(Icons.format_list_bulleted),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, child) {
        // Loading State
        if (_manager.currentPosition == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text("Acquiring GPS Signal", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          );
        }

        final mapStack = _buildMapStack();

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Semantics(
              sortKey: const OrdinalSortKey(0.0),
              header: true,
              label: 'Turn-by-turn Navigation',
              child: Focus(
                focusNode: _titleFocusNode,
                child: Semantics(
                  focused: true,
                  child: const Opacity(
                    opacity: 0.0,
                    child: Text('Turn-by-turn Navigation'),
                  ),
                ),
              ),
            ),
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Semantics(
                sortKey: const OrdinalSortKey(1.0),
                label: 'Go back to locations list',
                button: true,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: const BackButton(color: Colors.black),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Semantics(
                  sortKey: const OrdinalSortKey(2.0),
                  label:
                  '${_manager.voiceEnabled ? 'Mute' : 'Unmute'} voice guidance. ${_manager.voiceEnabled ? 'Voice guidance on' : 'Voice guidance off'}',
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: IconButton(
                      onPressed: _manager.toggleVoice,
                      icon: Icon(
                        _manager.voiceEnabled ? Icons.volume_up : Icons.volume_off,
                        color: Colors.black87,
                      ),
                      tooltip: _manager.voiceEnabled ? 'Mute guidance' : 'Unmute guidance',
                    ),
                  ),
                ),
              )
            ],
          ),

          // ✅ Split layout when detection is enabled
          body: widget.withDetection
              ? Column(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.black,
                  child: _DetectionSection(),
                ),
              ),
              Expanded(
                flex: 1,
                child: mapStack,
              ),
            ],
          )
              : mapStack,
        );
      },
    );
  }
}

///
/// Detection section that selects a camera and shows live detection panel.
/// Separated to keep MapsNavigation clean.
///
class _DetectionSection extends StatefulWidget {
  @override
  State<_DetectionSection> createState() => _DetectionSectionState();
}

class _DetectionSectionState extends State<_DetectionSection> {
  Future<List<CameraDescription>>? _camsFuture;

  @override
  void initState() {
    super.initState();
    _camsFuture = availableCameras();
  }

  CameraDescription _pickBestCamera(List<CameraDescription> cams) {
    // Prefer back camera if available
    for (final c in cams) {
      if (c.lensDirection == CameraLensDirection.back) return c;
    }
    return cams.first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CameraDescription>>(
      future: _camsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No camera available', style: TextStyle(color: Colors.white)),
          );
        }

        final cam = _pickBestCamera(snapshot.data!);
        return DepthLivePanel(camera: cam);
      },
    );
  }
}

///
/// Embedded detection widget (no Scaffold / no MaterialApp).
/// Shows live camera preview + server annotated frame.
///
class DepthLivePanel extends StatefulWidget {
  final CameraDescription camera;
  const DepthLivePanel({super.key, required this.camera});

  @override
  State<DepthLivePanel> createState() => _DepthLivePanelState();
}

class _DepthLivePanelState extends State<DepthLivePanel> {
  CameraController? _controller;
  Future<void>? _initFuture;

  Timer? _timer;
  bool _processing = false;

  Uint8List? _annotatedPng;
  String? _error;

  final Speaker _speaker = Speaker();

  // ✅ takePicture() is slow; do not spam.
  static const Duration _interval = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    _initFuture = _controller!.initialize().then((_) async {
      await _speaker.init();
      _timer = Timer.periodic(_interval, (_) => _captureAndSend());
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = 'Camera init error: $e');
    });
  }

  Future<void> _captureAndSend() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_processing) return;

    _processing = true;

    try {
      final XFile file = await c.takePicture();
      final bytes = await file.readAsBytes();

      // 1) JSON -> phrase -> speak
      //    (your DetectService must return something like { detections: [...] })
      final jsonResp = await DetectService.detectWithDepthJson(bytes);

// ✅ Prefer server narrative
      final phrase = jsonResp.narrative.trim();

// ✅ Fallback to local policy if server returns empty
      final fallback = phraseFromDetections(jsonResp.detections);

      final toSpeak = phrase.isNotEmpty ? phrase : (fallback ?? '');
      if (toSpeak.isNotEmpty) {
        await _speaker.say(toSpeak);
      }

      // 2) PNG -> UI
      final png = await DetectService.detectWithDepth(bytes);

      if (!mounted) return;
      setState(() {
        _annotatedPng = png;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Detect error: $e');
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speaker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || c == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: Row(
                children: [
                  // Left: smooth local preview
                  Expanded(
                    flex: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CameraPreview(c),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Right: API “video feed” (annotated frames)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _annotatedPng == null
                          ? const Center(
                        child: Text(
                          'Waiting for annotated feed…',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _annotatedPng!,
                          gaplessPlayback: true,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}