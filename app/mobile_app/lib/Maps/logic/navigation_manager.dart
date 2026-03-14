import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'; // Unified Voice
import 'package:flutter/services.dart'; // Haptics
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_compass/flutter_compass.dart'; // Compass
import 'package:vibration/vibration.dart';

import '../models/route_models.dart';

class NavigationManager extends ChangeNotifier {
  // State
  LatLng? _currentPosition;
  double _currentHeading = 0.0;
  double _lastStableHeading = 0.0; // For smoothing
  RouteResult _route = RouteResult.empty();
  int _currentStepIndex = 0;
  bool _isRouting = false;
  
  // Guidance state
  double? _metersToNextManeuver;
  double? _remainingMeters;
  String _bannerText = "Calculating...";
  String _lastSpoken = "";
  
  // Tools
  StreamSubscription<Position>? _posSub;
  StreamSubscription<CompassEvent>? _compassSub;
  final FlutterTts _tts = FlutterTts();

  // Config
  bool _voiceEnabled = true;
  bool _isSpeaking = false;
  DateTime _lastRerouteAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPeriodicSpeakAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHapticAt = DateTime.fromMillisecondsSinceEpoch(0); // Haptic Cooldown
  bool _isAligned = false; // Haptic State

  LatLng? _destination;
  double _currentAccuracy = 0.0;

  // Getters
  LatLng? get currentPosition => _currentPosition;
  double get currentHeading => _currentHeading;
  List<LatLng> get routePoints => _route.points;
  List<RouteStep> get steps => _route.steps;
  int get currentStepIndex => _currentStepIndex;
  bool get isRouting => _isRouting;
  String get bannerText => _bannerText;
  bool get voiceEnabled => _voiceEnabled;
  bool get isSpeaking => _isSpeaking;
  double? get remainingMeters => _remainingMeters;
  double? get metersToNextManeuver => _metersToNextManeuver;

  NavigationManager() {
    _initTts();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _compassSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    
    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });
    
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  Future<void> initLocation() async {
    if (await Permission.location.request().isGranted) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _updatePosition(pos);
    } else {
        _bannerText = "Location permission needed";
        notifyListeners();
    }
  }

  Future<void> startLiveTracking() async {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, 
    );

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _updatePosition(pos);
        _checkProgress();
        
        // Auto-route info
        if (_destination != null && _route.points.isEmpty && !_isRouting) {
             routeToDestination();
        }
      },
      onError: (e) => debugPrint("Location stream error: $e"),
    );
    
    // Compass Listener with SMOOTHING
    _compassSub?.cancel();
    // Compass Listener with SMOOTHING & JITTER CONTROL
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
        if (event.heading == null) return;
        
        double rawHeading = event.heading!;
        if (rawHeading < 0) rawHeading += 360;

        // 1. Deadband: Ignore tiny changes (< 2 degrees) to prevent micro-jitter
        double diff = (rawHeading - _currentHeading).abs();
        if (diff > 180) diff = 360 - diff;
        if (diff < 2.0) return; 

        // 2. Low-Pass Filter: smooth = old*0.8 + new*0.2
        // If the gap is huge (wrapping 359->1), snap to it, otherwise smooth.
        if (diff > 45.0) {
           _currentHeading = rawHeading;
        } else {
           // Handle wrap-around for averaging
           double oldH = _currentHeading;
           if ((rawHeading - oldH).abs() > 180) {
             if (rawHeading > oldH) oldH += 360;
             else rawHeading += 360;
           }
           double smoothed = (oldH * 0.8) + (rawHeading * 0.2);
           if (smoothed >= 360) smoothed -= 360;
           _currentHeading = smoothed;
        }
        
        notifyListeners();
        
        // Check alignment for haptics if moving
        if (_route.steps.isNotEmpty && _metersToNextManeuver != null) {
             _checkHaptics();
        }
    });
  }

  void stopTracking() {
    _posSub?.cancel();
    _compassSub?.cancel();
    _posSub = null;
    _compassSub = null;
  }

  void _updatePosition(Position pos) {
    _currentPosition = LatLng(pos.latitude, pos.longitude);
    _currentAccuracy = pos.accuracy;
    notifyListeners();
  }

  // ----------------------------
  // Routing
  // ----------------------------

  Future<void> startNavigation(LatLng dest) async {
    _destination = dest;
    if (_currentPosition != null) {
        await routeToDestination(isReroute: false);
    } else {
        _bannerText = "Waiting for location...";
        notifyListeners();
    }
    await startLiveTracking();
  }

  Future<void> toggleVoice() async {
    _voiceEnabled = !_voiceEnabled;
    if (!_voiceEnabled) {
      await _tts.stop();
    } else {
      _warnedAction = false; // Allow re-announce
      _checkProgress(); // Trigger immediate check
    }
    notifyListeners();
  }

  // ----------------------------
  // Logic (Strict Rules)
  // ----------------------------

  List<LatLng> get remainingPolyline {
      if (_route.points.isEmpty || _currentPosition == null) return [];
      int closestIndex = 0;
      double minD = double.infinity;
      for(int i=0; i<_route.points.length; i++) {
          final d = _haversineMeters(_currentPosition!, _route.points[i]);
          if (d < minD) {
              minD = d;
              closestIndex = i;
          }
      }
      return _route.points.sublist(closestIndex);
  }

  // Step States
  bool _warned30m = false;
  bool _warnedAction = false;

  void _checkProgress() {
    if (_route.steps.isEmpty || _currentPosition == null) return;

    // 1. Off-Route (>40m)
    if (_route.points.isNotEmpty) {
       final distToRoute = _distanceToPolylineMeters(_currentPosition!, _route.points);
       if (distToRoute > 40.0) {
         final now = DateTime.now();
           if (now.difference(_lastRerouteAt) > const Duration(seconds: 10)) {
             _lastRerouteAt = now;
             _speak("You are off route. Rerouting.", force: true);
             HapticFeedback.vibrate(); // Double vibration (simulated by heavy + light)
             Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.lightImpact());
             routeToDestination(isReroute: true);
             return;
           }
       }
    }

    // 2. Arrival (<15m)
    if (_destination != null) {
        final distToDest = _haversineMeters(_currentPosition!, _destination!);
        if (distToDest <= 15.0) {
            if (_bannerText != "Arrived") {
                _speak("You have arrived at your destination.", force: true);
                stopTracking();
                _bannerText = "Arrived";
                notifyListeners();
            }
            return;
        }
    }

    // 3. Step Logic
    if (_currentStepIndex < _route.steps.length) {
      final currentStep = _route.steps[_currentStepIndex];
      // Distance to the maneuver POINT
      final distToManeuver = _haversineMeters(_currentPosition!, currentStep.maneuver.latLng);
      _metersToNextManeuver = distToManeuver;

      // Completion Logic
      // If we spoke the "NOW" command, wait until we pass the point or get extremely close (<5m)
      // then switch to next step.
      if (_warnedAction && distToManeuver < 10) {
           // We are essentially AT the turn.
           // Switch to next step effectively?
           // For walking, we generally want to switch AFTER the turn is done.
           // Simple heuristic: If distance starts INCREASING, we passed it.
           // Or just switch when very close.
           if (distToManeuver < 5) {
                _advanceStep();
           }
      }

      _handleVoiceTriggers(distToManeuver, currentStep);
    }
    
    _updateGuidanceNumbers();
    _periodicReassurance();

    notifyListeners();
  }
  
  void _advanceStep() {
      if (_currentStepIndex < _route.steps.length - 1) {
          _currentStepIndex++;
          _warned30m = false;
          _warnedAction = false;
          // Do NOT speak immediately. Wait for distance logic to trigger "In X meters".
      }
  }

  void _handleVoiceTriggers(double dist, RouteStep step) {
      if (step.maneuver.type == 'arrive') return; 
      
      final instruction = getInstruction(step);

      // A) ACTION (<= 10m) -> "Turn right now"
      if (dist <= 10 && !_warnedAction) {
          _warnedAction = true;
          if (_currentAccuracy > 30) {
               _speak("Approximately, $instruction now.");
          } else {
               _speak("$instruction now.");
          }
      } 
      // B) WARNING (<= 30m) -> "In 30 meters, turn right"
      else if (dist <= 30 && dist > 10 && !_warned30m) {
          _warned30m = true;
          // Round to nearest 10
          final rounded = (dist / 10).round() * 10;
          _speak("In $rounded meters, $instruction.");
      }
  }

  // ----------------------------
  // Haptics (Minimal)
  // ----------------------------
  void _checkHaptics() {
    if (_currentPosition == null || _route.steps.isEmpty || _currentStepIndex >= _route.steps.length) return;

    // Only vibrate if moving (good accuracy)
    if (_currentAccuracy > 30) return;

    final step = _route.steps[_currentStepIndex];

    // Bearing from current position to the next maneuver point
    final bearingToTarget = _calculateBearing(_currentPosition!, step.maneuver.latLng);

    // Calculate the angular difference between where user is facing and where they should go
    double error = (bearingToTarget - _currentHeading).abs();
    if (error > 180) error = 360 - error;

    // Aligned if within 90 degrees (facing generally the right direction)
    // Misaligned if error > 90 degrees (facing opposite or perpendicular)
    bool aligned = error <= 90;

    final now = DateTime.now();

    if (!aligned && _isAligned) {
      // Just became MISALIGNED (was aligned, now not)
      // Give a single 0.5 second vibration
      if (now.difference(_lastHapticAt) > const Duration(milliseconds: 600)) {
        Vibration.vibrate(duration: 500);
        _lastHapticAt = now;
        debugPrint("Haptic: Misaligned (>90°) - Single vibration");
      }
    }
    else if (aligned && !_isAligned) {
      // Just became ALIGNED (was misaligned, now aligned)
      // Give two continuous 0.5 second vibrations
      if (now.difference(_lastHapticAt) > const Duration(milliseconds: 600)) {
        Vibration.vibrate(duration: 500);
        Future.delayed(const Duration(milliseconds: 550), () {
          Vibration.vibrate(duration: 500);
        });
        _lastHapticAt = now;
        debugPrint("Haptic: Aligned - Double vibration");
      }
    }

    _isAligned = aligned;
  }

  double _calculateBearing(LatLng start, LatLng end) {
    var lat1 = _deg2rad(start.latitude);
    var lon1 = _deg2rad(start.longitude);
    var lat2 = _deg2rad(end.latitude);
    var lon2 = _deg2rad(end.longitude);
    var dLon = lon2 - lon1;
    var y = sin(dLon) * cos(lat2);
    var x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    var brng = atan2(y, x);
    return (_rad2deg(brng) + 360) % 360;
  }
  double _rad2deg(double r) => r * (180.0 / pi);

  void _periodicReassurance() {
    // Only if we actually have an active route
    if (_route.steps.isEmpty || _currentPosition == null) return;
    
    final now = DateTime.now();
    // Every 5 seconds
    if (now.difference(_lastPeriodicSpeakAt) > const Duration(seconds: 5)) {
         _lastPeriodicSpeakAt = now;
         
         // Speak the current guidance (e.g. "50 m Turn right")
         // Remove newlines so TTS reads it naturally
         String textToSpeak = _bannerText.replaceAll('\n', ' ');
         
         // Only speak if it's not "Calculating..." or similar non-directional text
         // or it's genuinely useful. _bannerText usually has distance + instruction.
         if (textToSpeak != "Calculating..." && textToSpeak != "Waiting for location...") {
            _speak(textToSpeak, force: true);
         }
    }
  }

  void _updateGuidanceNumbers() {
    if (_route.steps.isEmpty || _currentStepIndex >= _route.steps.length) return;
    
    final currentStep = _route.steps[_currentStepIndex];
    double remaining = 0;
    if (_metersToNextManeuver != null) remaining += _metersToNextManeuver!;
    for(int i = _currentStepIndex + 1; i < _route.steps.length; i++) {
        remaining += _route.steps[i].distance;
    }
    _remainingMeters = remaining;

    final instruction = getInstruction(currentStep);
    
    if (_metersToNextManeuver != null) {
        _bannerText = "${_formatDistance(_metersToNextManeuver!)}\n$instruction";
    } else {
        _bannerText = instruction;
    }
    notifyListeners();
  }

  String _formatDistance(double m) {
      if (m > 100) return "${(m/10).round() * 10} m";
      if (m > 20) return "${(m/5).round() * 5} m";
      return "Now";
  }

  // ----------------------------
  // Instructions (Minimal)
  // ----------------------------

  String getInstruction(RouteStep step) {
    final m = step.maneuver;
    final type = m.type;
    final mod = m.modifier;
    
    // NORMALIZE PHRASING
    if (type == 'turn') {
        if (mod.contains('left')) return "Turn left";
        if (mod.contains('right')) return "Turn right";
        if (mod.contains('uturn')) return "Turn around";
        return "Continue straight";
    }
    if (type == 'depart') return "Continue straight";
    if (type == 'arrive') return "You have arrived"; 
    // Roundabouts
    if (type == 'roundabout' || type == 'rotary') return "Enter roundabout";
    if (type == 'end of road') {
        if (mod.contains('left')) return "Turn left";
        if (mod.contains('right')) return "Turn right";
        return "Turn";
    }
    // Merges/Forks -> Simplify to turn if obvious, else straight
    if (type == 'merge' || type == 'fork') {
         if (mod.contains('left')) return "Keep left";
         if (mod.contains('right')) return "Keep right";
         return "Continue straight";
    }
    
    return "Continue straight";
  }

  Future<void> _speak(String text, {bool force = false}) async {
    if (!_voiceEnabled) return;
    
    // Deduplication logic: don't repeat the same phrase unless forced
    if (!force && text == _lastSpoken) {
      return;
    }

    _lastSpoken = text;
    _lastPeriodicSpeakAt = DateTime.now();

    // Use flutter_tts instead of TalkBack for clearer, non-interruptible voice
    await _tts.stop();
    await _tts.speak(text);
  }

  // ----------------------------
  // OSRM & Helpers
  // ----------------------------

  Future<void> routeToDestination({bool isReroute = false}) async {
    if (_currentPosition == null || _destination == null) return;
    _isRouting = true;
    _bannerText = "Calculating...";
    notifyListeners();

    try {
      final result = await _fetchRouteOSRM(_currentPosition!, _destination!);
      _route = result;
      _currentStepIndex = 0;
      _lastRerouteAt = DateTime.now();
      
      _warned30m = false;
      _warnedAction = false;
      
      _updateGuidanceNumbers();
      
      if (!isReroute) {
          await _speak("Navigation started.", force: true);
      } 
      
    } catch (e) {
      _bannerText = "Error calculating route";
    } finally {
      _isRouting = false;
      notifyListeners();
    }
  }

  Future<RouteResult> _fetchRouteOSRM(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/'
      '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception("Failed");

    final data = jsonDecode(res.body);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return RouteResult.empty();

    final route0 = routes[0];
    final distance = (route0['distance'] as num?)?.toDouble();
    final duration = (route0['duration'] as num?)?.toDouble();
    
    final coords = route0['geometry']['coordinates'] as List;
    final points = coords.map<LatLng>((c) => LatLng(
      (c[1] as num).toDouble(),
      (c[0] as num).toDouble(),
    )).toList();
    
    final legs = route0['legs'] as List?;
    final stepsJson = (legs != null && legs.isNotEmpty) ? legs[0]['steps'] as List : [];
    final steps = stepsJson.map((s) => RouteStep.fromJson(s)).toList();

    return RouteResult(
        points: points, 
        steps: steps, 
        distanceMeters: distance, 
        durationSeconds: duration
    );
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return R * c;
  }

  double _deg2rad(double d) => d * (pi / 180.0);
  
  double _distanceToPolylineMeters(LatLng p, List<LatLng> poly) {
    if (poly.isEmpty) return double.infinity;
    double best = double.infinity;
    for (int i = 0; i < poly.length - 1; i++) {
        final d = _distancePointToSegmentMeters(p, poly[i], poly[i + 1]);
        if (d < best) best = d;
    }
    return best;
  }
  
  double _distancePointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final x = p.longitude;
    final y = p.latitude;
    final x1 = a.longitude;
    final y1 = a.latitude;
    final x2 = b.longitude;
    final y2 = b.latitude;

    final A = x - x1;
    final B = y - y1;
    final C = x2 - x1;
    final D = y2 - y1;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    double param = -1;
    if (lenSq != 0) param = dot / lenSq;

    double xx, yy;

    if (param < 0) { xx = x1; yy = y1; }
    else if (param > 1) { xx = x2; yy = y2; }
    else { xx = x1 + param * C; yy = y1 + param * D; }

    return _haversineMeters(p, LatLng(yy, xx));
  }
}
