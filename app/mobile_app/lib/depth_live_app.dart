import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'tts/speaker.dart';
import 'tts/speech_policy.dart';
import 'depth_services/detect_service.dart';


class DepthLiveApp extends StatelessWidget {
  final CameraDescription camera;
  const DepthLiveApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netra – Live Feed',
      theme: ThemeData.dark(),
      home: DepthLivePage(camera: camera),
    );
  }
}

class DepthLivePage extends StatefulWidget {
  final CameraDescription camera;
  const DepthLivePage({super.key, required this.camera});

  @override
  State<DepthLivePage> createState() => _DepthLivePageState();
}

class _DepthLivePageState extends State<DepthLivePage> {
  CameraController? _controller;
  Future<void>? _initFuture;

  Timer? _timer;
  bool _processing = false;

  Uint8List? _annotatedPng;
  String? _error;
  final Speaker _speaker = Speaker();

  // takePicture() is slow: 800–1500ms is realistic
  static const Duration _interval = Duration(milliseconds: 10);

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
      final yoloResp = await DetectService.detectYoloJson(bytes);
      final phrase = yoloResp.narrative; // already clean speech-friendly
      if (phrase.isNotEmpty) {
        await _speaker.say(phrase);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Netra – API Annotated Feed')),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done || c == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      // Left: smooth local preview
                      Expanded(
                        flex: 2,
                        child: CameraPreview(c),
                      ),
                      const SizedBox(width: 8),
                      // Right: API “video feed” (annotated frames)
                      Expanded(
                        flex: 2,
                        child: Container(
                          color: Colors.black,
                          child: _annotatedPng == null
                              ? const Center(
                            child: Text(
                              'Waiting for annotated feed…',
                              textAlign: TextAlign.center,
                            ),
                          )
                              : Image.memory(
                            _annotatedPng!,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
